require "rails_helper"
require "support/identity_helpers"

# Two requests at once on the same meal, each on its own connection. The meal is locked for each change,
# so the final state is one of the two orders and never a mix.
RSpec.describe "Nutrition concurrency" do
  self.use_transactional_tests = false

  let(:user) { Identity::User.create!(email: "cc-#{SecureRandom.hex(4)}@example.test", password: IdentityHelpers::PASSWORD, adult_confirmed_at: Time.current) }
  let!(:rice) do
    FoodCatalog::CatalogItem.create!(source: "usda_fdc", source_version: "v1", source_item_id: SecureRandom.hex(3), license: "CC0-1.0", name: "Arroz",
                                     name_pt: "Arroz", kind: "ingredient",
                                     nutrients_per_100g: { "energy_kcal" => 130, "protein_g" => 2.7, "carbs_g" => 28, "fat_g" => 0.3 })
  end

  after { ActiveRecord::Base.connection.execute("TRUNCATE users, food_entries, food_catalog, consent_records, outbox_events, audit_events CASCADE") }

  def entry(status: "analyzed")
    Nutrition::FoodEntry.create!(user_id: user.id, status:, source: "photo", client_request_id: SecureRandom.uuid, meal_at: Time.current, local_date: Date.current)
  end

  def item(meal)
    numbers = Nutrition::Calculator.item(per_100g: FoodCatalog::Api.nutrients_for(catalog_item_id: rice.id).per_100g, grams_min: 120, grams_likely: 150, grams_max: 180)
    Nutrition::FoodItem.create!(food_entry: meal, display_name: "Arroz", catalog_item_id: rice.id, quantity_grams_min: 120, quantity_grams_likely: 150,
                                quantity_grams_max: 180, confidence: 0.9, origin: "ai", nutrition_source_ref: { source: "usda_fdc", version: "v1", id: "1" }, **numbers)
  end

  # Runs each block on its own thread and connection, released together. Returns the values in order.
  def together(*blocks)
    gate = Queue.new
    threads = blocks.map do |block|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          block.call
        end
      end
    end
    blocks.size.times { gate << true }
    threads.map(&:value)
  end

  it "two confirmations of the same meal give one confirmed state and both succeed" do
    meal = entry
    item(meal)

    results = together(*Array.new(2) { -> { Nutrition::Api.confirm_entry(user_id: user.id, food_entry_id: meal.id) } })

    expect(results).to all(be_ok)
    expect(results.map(&:status)).to all(eq("confirmed"))
    expect(meal.reload).to have_attributes(status: "confirmed")
    expect(meal.confirmed_at).to be_present
    expect(Nutrition::FoodEntry.where(status: "confirmed").count).to eq(1)
  end

  describe "a correction racing with the analysis arriving" do
    let(:analysis) do
      info = FoodAi::ItemInfo.new(name: "Arroz", preparation: nil, confidence: 0.9, grams_min: 100, grams_likely: 100, grams_max: 100,
                                       household_measure: nil, hidden_ingredients_possible: false)
      FoodAi::Api::AnalysisInfo.new(id: SecureRandom.uuid, status: "succeeded", items: [ info ], note_codes: [])
    end
    let(:event) { Struct.new(:payload, :user_id).new({ "food_entry_id" => nil, "outcome" => "analyzed", "analysis_id" => analysis.id }, user.id) }

    before { allow(FoodAi::Api).to receive(:analysis).with(analysis_id: analysis.id).and_return(analysis) }

    it "a delivery arriving again does not undo the correction nor add items" do
      meal = entry(status: "processing")
      event.payload["food_entry_id"] = meal.id
      Nutrition::ApplyAnalysis.call(event)
      original = meal.reload.items.sole

      together(
        -> { Nutrition::Api.correct_item(user_id: user.id, food_entry_id: meal.id, item_id: original.id, changes: { grams_likely: 300 }) },
        -> { Nutrition::ApplyAnalysis.call(event) }
      )

      meal.reload
      expect(meal.items.count).to eq(2)
      visible = meal.visible_items.sole
      expect(visible).to have_attributes(origin: "user", corrected_from_item_id: original.id, quantity_grams_likely: BigDecimal("300"))
      expect(original.reload.hidden_reason).to eq("corrected")
      expect(meal.calories_likely).to eq(visible.calories_likely)
    end

    it "a correction of an item the analysis has not created yet leaves only the analysis's items" do
      meal = entry(status: "processing")
      event.payload["food_entry_id"] = meal.id

      results = together(
        -> { Nutrition::Api.correct_item(user_id: user.id, food_entry_id: meal.id, item_id: SecureRandom.uuid, changes: { grams_likely: 300 }) },
        -> { Nutrition::ApplyAnalysis.call(event) }
      )

      expect(results.first).not_to be_a(Nutrition::Api::EntryInfo)
      meal.reload
      expect(meal.status).to eq("analyzed")
      expect(meal.items.pluck(:origin)).to eq([ "ai" ])
      expect(meal.calories_likely).to eq(meal.items.sole.calories_likely)
    end
  end

  describe "a manual meal with the same client_request_id" do
    def manual
      Nutrition::Api.create_manual_entry(user_id: user.id, client_request_id: "same", meal_at: Time.current.iso8601,
                                         items: [ { catalog_item_id: rice.id, grams_likely: 100 } ])
    end

    it "two requests at once create one meal" do
      results = together(*Array.new(3) { -> { manual } })

      expect(results).to all(be_ok)
      expect(results.map(&:id).uniq.size).to eq(1)
      expect(results.count(&:created)).to eq(1)
      expect(Nutrition::FoodEntry.count).to eq(1)
      expect(Nutrition::FoodItem.count).to eq(1)
    end

    it "gives the existing meal when the uniqueness validation loses the race" do
      winner = Nutrition::FoodEntry.create!(user_id: user.id, client_request_id: "same", meal_at: Time.current, local_date: Date.current, source: "manual",
                                            status: "confirmed", confirmed_at: Time.current)
      taken = Nutrition::FoodEntry.new
      taken.errors.add(:client_request_id, :taken)
      calls = 0
      allow(Nutrition::FoodEntry).to receive(:find_by).and_wrap_original { |original, *args| (calls += 1) == 1 ? nil : original.call(*args) }
      allow(Nutrition::FoodEntry).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(taken))

      result = manual

      expect(result).to be_ok
      expect(result).to have_attributes(id: winner.id, created: false)
    end

    it "does not hide any other validation failure" do
      other = Nutrition::FoodEntry.new
      other.errors.add(:meal_at, :blank)
      allow(Nutrition::FoodEntry).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(other))

      expect { manual }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end

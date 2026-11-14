require "rails_helper"
require "support/outbox_helpers"
require "support/food_ai_pipeline"

RSpec.describe "nutrition.apply_analysis", :real_consumers do
  self.use_transactional_tests = false

  include OutboxHelpers
  include FoodAiPipeline

  let(:user) { create_user }
  let(:photo) { create_photo(user:) }
  let(:entry) do
    Nutrition::FoodEntry.create!(id: photo.food_entry_id, user_id: user.id, photo_id: photo.id, source: "photo", status: "processing",
                                 client_request_id: SecureRandom.uuid, meal_at: Time.current, local_date: Date.current)
  end

  before do
    use_operator_consent_version
    grant_food_photo_ai(user.id)
    add_food("Rice", energy_kcal: 130, protein_g: 2.7, carbs_g: 28, fat_g: 0.3)
    entry
  end

  after { ActiveRecord::Base.connection.execute("TRUNCATE users, food_photos, food_entries, food_catalog, food_analysis_results, ai_usage_records, consent_records, outbox_events, audit_events CASCADE") }

  def add_food(name, kind: "ingredient", source: "usda_fdc", **nutrients)
    FoodCatalog::CatalogItem.create!(source:, source_version: "v1", source_item_id: SecureRandom.hex(3), license: "CC0-1.0", name:, name_pt: name, kind:,
                                     nutrients_per_100g: nutrients.transform_keys(&:to_s))
  end

  def analyze(payload = FoodAiAdapter::RICE)
    scripted(payload)
    run_until_settled(photo)
    run_publisher_now
  end

  def rice_with(*extra)
    FoodAiAdapter::RICE.merge("items" => FoodAiAdapter::RICE["items"] + extra)
  end

  def mystery
    { "name" => "xyzzy zork", "preparation" => "raw", "confidence" => 0.9, "hidden_ingredients_possible" => false,
      "portion" => { "grams_min" => 50, "grams_likely" => 60, "grams_max" => 70, "household_measure" => "1 piece" } }
  end

  it "creates the items from the catalog, the totals, and the source reference" do
    analyze

    entry.reload
    item = entry.items.sole
    expect(entry.status).to eq("analyzed")
    expect(entry.estimate_partial).to be(false)
    expect(item).to have_attributes(display_name: "Rice", calories_min: BigDecimal("156"), calories_likely: BigDecimal("195"),
                                    calories_max: BigDecimal("234"), origin: "ai", household_measure: "1 scoop", confidence: BigDecimal("0.9"))
    expect(entry).to have_attributes(calories_min: BigDecimal("156"), calories_likely: BigDecimal("195"), calories_max: BigDecimal("234"))
  end

  it "each item carries the nutrition source" do
    analyze

    catalog = FoodCatalog::CatalogItem.sole
    expect(entry.items.sole.nutrition_source_ref).to eq("source" => "usda_fdc", "version" => "v1", "id" => catalog.source_item_id)
    expect(entry.items.sole.catalog_item_id).to eq(catalog.id)
  end

  it "an item the catalog does not know stays unknown, without numbers, and the estimate is partial" do
    analyze(rice_with(mystery))

    entry.reload
    unknown = entry.items.find_by(display_name: "xyzzy zork")
    expect(unknown).to have_attributes(catalog_item_id: nil, calories_likely: nil, nutrition_source_ref: nil)
    expect(entry.estimate_partial).to be(true)
    expect(entry.calories_likely).to eq(BigDecimal("195"))
  end

  it "only unknown items leave the calories null" do
    analyze(FoodAiAdapter::RICE.merge("items" => [ mystery ]))

    entry.reload
    expect(entry).to have_attributes(status: "analyzed", estimate_partial: true, calories_min: nil, calories_likely: nil, calories_max: nil)
    expect(entry.items.count).to eq(1)
  end

  it "the model is never the source of calories" do
    with_calories = FoodAiAdapter::RICE.merge("items" => [ FoodAiAdapter::RICE["items"].first.merge("calories" => 9999) ])
    analyze(with_calories)

    expect(Nutrition::FoodItem.count).to eq(0)
    expect(entry.reload.status).to eq("failed")
    expect(entry.calories_likely).to be_nil
  end

  it "applying the same event twice creates the items once" do
    analyze
    event = Shared::Outbox::Event.find_by!(name: "food_analysis.completed")

    2.times { Nutrition::ApplyAnalysis.call(event) }

    expect(entry.items.count).to eq(1)
    expect(entry.reload.status).to eq("analyzed")
  end

  it "no_food sets result_code and no numbers" do
    analyze(FoodAiAdapter::NO_FOOD)

    entry.reload
    expect(entry).to have_attributes(status: "analyzed", result_code: "no_food", calories_min: nil, estimate_partial: false)
    expect(entry.items.count).to eq(0)
  end

  it "unreadable sets result_code and no numbers" do
    analyze(FoodAiAdapter::EMPTY_FOOD)

    expect(entry.reload).to have_attributes(status: "analyzed", result_code: "unreadable", calories_min: nil)
    expect(entry.items.count).to eq(0)
  end

  it "failed sets the status failed" do
    scripted(FoodAi::PermanentProviderError.new("bad_request"))
    run_job(photo)
    run_publisher_now

    expect(entry.reload).to have_attributes(status: "failed", calories_min: nil)
  end

  it "does not overwrite a confirmed meal" do
    analyze
    entry.update!(status: "confirmed", confirmed_at: Time.current)
    entry.items.destroy_all
    event = Shared::Outbox::Event.find_by!(name: "food_analysis.completed")

    Nutrition::ApplyAnalysis.call(event)

    expect(entry.reload.status).to eq("confirmed")
    expect(entry.items.count).to eq(0)
  end

  describe "cancelled" do
    def cancelled(food_entry_id: entry.id, user_id: user.id)
      Shared::Outbox::Event.new(name: "food_analysis.completed", user_id:, version: 1,
                                payload: { "analysis_id" => nil, "food_entry_id" => food_entry_id, "outcome" => "cancelled",
                                           "error_code" => "consent_revoked" })
    end

    it "cancelled deletes the entry and its items" do
      Nutrition::FoodItem.create!(food_entry: entry, display_name: "x", quantity_grams_min: 1, quantity_grams_likely: 2, quantity_grams_max: 3)

      Nutrition::ApplyAnalysis.call(cancelled)

      expect(Nutrition::FoodEntry.where(id: entry.id)).not_to exist
      expect(Nutrition::FoodItem.count).to eq(0)
    end

    it "tolerates a missing analysis_id, a failed entry, a gone entry and a repeat" do
      entry.update!(status: "failed")

      expect { 2.times { Nutrition::ApplyAnalysis.call(cancelled) } }.not_to raise_error
      expect(Nutrition::FoodEntry.where(id: entry.id)).not_to exist
    end

    it "a photo not linked yet (food_entry_id nil) is a no-op" do
      expect { Nutrition::ApplyAnalysis.call(cancelled(food_entry_id: nil)) }.not_to raise_error
      expect(Nutrition::FoodEntry.where(id: entry.id)).to exist
    end

    it "does not delete another person's meal" do
      Nutrition::ApplyAnalysis.call(cancelled(user_id: create_user("other").id))

      expect(Nutrition::FoodEntry.where(id: entry.id)).to exist
    end

    it "does not delete a confirmed meal" do
      entry.update!(status: "confirmed", confirmed_at: Time.current)

      Nutrition::ApplyAnalysis.call(cancelled)

      expect(Nutrition::FoodEntry.where(id: entry.id)).to exist
    end
  end
end

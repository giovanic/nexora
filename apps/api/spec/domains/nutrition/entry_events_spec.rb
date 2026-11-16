require "rails_helper"
require "support/outbox_helpers"
require "support/food_ai_pipeline"

RSpec.describe "Nutrition meal events", :real_consumers do
  include OutboxHelpers
  include FoodAiPipeline

  let(:user) { create_user }
  let(:photo) { create_photo(user:) }
  let!(:entry) do
    Nutrition::FoodEntry.create!(id: photo.food_entry_id, user_id: user.id, photo_id: photo.id, source: "photo", status: "analyzed",
                                 client_request_id: SecureRandom.uuid, meal_at: Time.current, local_date: Date.new(2026, 11, 16))
  end

  before do
    use_operator_consent_version
    grant_food_photo_ai(user.id)
    allow(FoodAi::PurgeObjectJob).to receive(:perform_async) { |id| FoodAi::PurgeObjectJob.new.perform(id) }
  end

  def events(name) = Shared::Outbox::Event.where(name:).order(:occurred_at, :id)

  def add_item
    Nutrition::FoodItem.create!(food_entry: entry, display_name: "arroz", quantity_grams_min: 100, quantity_grams_likely: 150, quantity_grams_max: 200,
                                origin: "ai", hidden_ingredients_possible: false)
  end

  describe "food_entry.confirmed" do
    it "is published in the transaction that confirms, with identifiers only" do
      add_item

      expect(Nutrition::Api.confirm_entry(user_id: user.id, food_entry_id: entry.id)).to be_ok
      expect(events("food_entry.confirmed").map(&:payload)).to eq([ { "food_entry_id" => entry.id, "local_date" => "2026-11-16" } ])
      expect(events("food_entry.confirmed").sole.user_id).to eq(user.id)
    end

    it "is not published again for a meal already confirmed, nor when the confirmation is refused" do
      Nutrition::Api.confirm_entry(user_id: user.id, food_entry_id: entry.id) # no item: refused
      expect(events("food_entry.confirmed")).to be_empty

      add_item
      2.times { Nutrition::Api.confirm_entry(user_id: user.id, food_entry_id: entry.id) }

      expect(events("food_entry.confirmed").count).to eq(1)
    end

    it "does not publish when the confirmation rolls back" do
      add_item
      allow_any_instance_of(Nutrition::FoodEntry).to receive(:update!).and_raise(ActiveRecord::StatementInvalid)

      expect { Nutrition::Api.confirm_entry(user_id: user.id, food_entry_id: entry.id) }.to raise_error(ActiveRecord::StatementInvalid)

      expect(events("food_entry.confirmed")).to be_empty
    end
  end

  describe "food_entry.deleted" do
    it "is published in the transaction that deletes the meal, with the meal and photo identifiers" do
      expect(Nutrition::Api.delete_entry(user_id: user.id, food_entry_id: entry.id)).to eq(:deleted)

      expect(events("food_entry.deleted").map(&:payload)).to eq([ { "food_entry_id" => entry.id, "photo_id" => photo.id } ])
    end

    it "does not publish for another person's meal" do
      other = create_user

      expect(Nutrition::Api.delete_entry(user_id: other.id, food_entry_id: entry.id)).to eq(:not_found)

      expect(events("food_entry.deleted")).to be_empty
      expect(Nutrition::FoodEntry.where(id: entry.id)).to exist
    end

    it "the consumer erases the photo, its analyses and its object, and unlinks the cost" do
      analysis = FoodAi::AnalysisResult.create!(photo_id: photo.id, user_id: user.id, food_entry_id: entry.id, provider: "fake", model: "fake-1",
                                                prompt_version: FoodAi::PromptCatalog.current.version, schema_version: 1, status: "succeeded",
                                                started_at: Time.current)
      FoodAi::UsageRecord.create!(analysis_id: analysis.id, user_id: user.id, provider: "fake", model: "fake-1", occurred_at: Time.current)
      # the synchronous shortcut is down: the event alone must do the work
      allow(FoodAi::Api).to receive(:erase_for_entry).and_raise(IOError)

      expect(Nutrition::Api.delete_entry(user_id: user.id, food_entry_id: entry.id)).to eq(:deleted)
      expect(photo.reload.status).to eq("stored")

      run_publisher_now

      expect(photo.reload.status).to eq("deleted")
      expect(FoodAi.storage.head(key: photo.object_key)).to be_nil
      expect(FoodAi::AnalysisResult.where(photo_id: photo.id)).to be_empty
      expect(FoodAi::UsageRecord.sole.analysis_id).to be_nil
    end

    it "is safe to deliver twice and leaves another meal's photo alone" do
      other_photo = create_photo(user:)
      Nutrition::Api.delete_entry(user_id: user.id, food_entry_id: entry.id)
      event = events("food_entry.deleted").sole

      2.times { Shared::Outbox::Event.transaction { FoodAi::EraseOnEntryDeleted.call(event) } }

      expect(photo.reload.status).to eq("deleted")
      expect(other_photo.reload.status).to eq("stored")
      expect(FoodAi.storage.head(key: other_photo.object_key)).to be_present
    end

    it "does not touch a photo of another person named by the event" do
      other_photo = create_photo(user: create_user)
      event = Shared::Outbox::Event.new(name: "food_entry.deleted", user_id: user.id, payload: { "food_entry_id" => SecureRandom.uuid, "photo_id" => other_photo.id })

      Shared::Outbox::Event.transaction { FoodAi::EraseOnEntryDeleted.call(event) }

      expect(other_photo.reload.status).to eq("stored")
    end

    it "a failure of the synchronous shortcut does not fail the deletion" do
      allow(FoodAi::Api).to receive(:erase_for_entry).and_raise(IOError)

      expect(Nutrition::Api.delete_entry(user_id: user.id, food_entry_id: entry.id)).to eq(:deleted)
      expect(Nutrition::FoodEntry.where(id: entry.id)).not_to exist
    end
  end
end

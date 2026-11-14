require "rails_helper"
require "support/outbox_helpers"
require "support/food_ai_pipeline"

RSpec.describe "Nutrition recovery jobs", :real_consumers do
  include OutboxHelpers
  include FoodAiPipeline

  let(:user) { create_user }

  before do
    use_operator_consent_version
    grant_food_photo_ai(user.id)
    allow(FoodAi::AnalyzeJob).to receive(:perform_async)
    allow(FoodAi::Api).to receive(:resume_analysis).and_call_original
  end

  def entry_for(photo, status:, updated_at: Time.current, created_at: updated_at)
    Nutrition::FoodEntry.create!(id: photo.food_entry_id, user_id: user.id, photo_id: photo.id, source: "photo", status:, client_request_id: SecureRandom.uuid,
                                 meal_at: Time.current, local_date: Date.current, created_at:, updated_at:)
  end

  it "revoking food_photo_ai deletes pending entries and their photos" do
    waiting = create_photo(user:, status: "awaiting_upload")
    entry = entry_for(waiting, status: "pending")

    Identity::Api.revoke_consent(user_id: user.id, purpose: "food_photo_ai")
    run_publisher_now

    expect(Nutrition::FoodEntry.where(id: entry.id)).not_to exist
    expect(waiting.reload.status).to eq("deleted")
  end

  describe Nutrition::AbandonedEntriesJob do
    it "pending entry older than one hour is deleted with its object" do
      photo = create_photo(user:, status: "awaiting_upload")
      entry = entry_for(photo, status: "pending", created_at: 61.minutes.ago)

      described_class.new.perform

      expect(Nutrition::FoodEntry.where(id: entry.id)).not_to exist
      expect(photo.reload.status).to eq("deleted")
      expect(FoodAi.storage.head(key: photo.object_key)).to be_nil
    end

    it "one hour is the strict boundary: exactly one hour is kept, one second more is deleted" do
      travel_to(Time.utc(2026, 11, 14, 12)) do
        exact = entry_for(create_photo(user:, status: "awaiting_upload"), status: "pending", created_at: 1.hour.ago)
        over = entry_for(create_photo(user:, status: "awaiting_upload"), status: "pending", created_at: 1.hour.ago - 1.second)

        described_class.new.perform

        expect(Nutrition::FoodEntry.where(id: exact.id)).to exist
        expect(Nutrition::FoodEntry.where(id: over.id)).not_to exist
      end
    end

    it "keeps a recent pending entry and entries in any other state" do
      recent_photo = create_photo(user:, status: "awaiting_upload")
      recent = entry_for(recent_photo, status: "pending", created_at: 30.minutes.ago)
      processing = entry_for(create_photo(user:), status: "processing", created_at: 3.hours.ago)
      confirmed = entry_for(create_photo(user:), status: "confirmed", created_at: 3.hours.ago)

      described_class.new.perform

      expect(Nutrition::FoodEntry.where(id: [ recent.id, processing.id, confirmed.id ]).count).to eq(3)
      expect(recent_photo.reload.status).to eq("awaiting_upload")
    end

    it "deletes an old pending entry whose photo is already gone, and is safe to repeat" do
      photo = create_photo(user:, status: "awaiting_upload")
      photo.update!(status: "deleted", deleted_at: Time.current)
      entry = entry_for(photo, status: "pending", created_at: 2.hours.ago)

      2.times { described_class.new.perform }

      expect(Nutrition::FoodEntry.where(id: entry.id)).not_to exist
    end

    it "leaves the meal when the photo is in use by an analysis" do
      photo = create_photo(user:)
      entry = entry_for(photo, status: "pending", created_at: 2.hours.ago)
      prompt = FoodAi::PromptCatalog.current
      FoodAi::AnalysisResult.create!(photo_id: photo.id, user_id: user.id, provider: "x", model: "y", prompt_version: prompt.version,
                                     schema_version: prompt.schema_version, status: "running", started_at: Time.current)

      described_class.new.perform

      expect(Nutrition::FoodEntry.where(id: entry.id)).to exist
      expect(photo.reload.status).to eq("stored")
    end

    it "does not delete another person's photo" do
      other = create_user
      photo = create_photo(user: other, status: "awaiting_upload")
      entry_for(photo, status: "pending", created_at: 2.hours.ago).update_columns(user_id: user.id)

      described_class.new.perform

      expect(photo.reload.status).to eq("awaiting_upload")
    end
  end

  describe Nutrition::StuckEntriesJob do
    let(:photo) { create_photo(user:) }

    it "does not touch a meal processing for less than 15 minutes" do
      entry_for(photo, status: "processing", updated_at: 14.minutes.ago)

      described_class.new.perform

      expect(FoodAi::AnalyzeJob).not_to have_received(:perform_async)
    end

    it "resumes a meal stuck in processing: the job is enqueued again and the meal stays processing" do
      entry = entry_for(photo, status: "processing", updated_at: 16.minutes.ago)

      described_class.new.perform

      expect(FoodAi::AnalyzeJob).to have_received(:perform_async).with(photo.id)
      expect(entry.reload.status).to eq("processing")
    end

    it "marks the meal failed when the photo is gone" do
      photo.update!(status: "deleted", deleted_at: Time.current)
      entry = entry_for(photo, status: "processing", updated_at: 20.minutes.ago)

      described_class.new.perform

      expect(entry.reload.status).to eq("failed")
    end

    it "refunds the quota unit when the meal fails because the photo is gone" do
      photo.update!(status: "deleted", deleted_at: Time.current)
      entry_for(photo, status: "processing", updated_at: 20.minutes.ago)

      described_class.new.perform

      expect(photo.reload.quota_refunded_at).to be_present
    end

    it "refunds the quota unit once" do
      photo.update!(status: "deleted", deleted_at: Time.current, quota_refunded_at: 2.days.ago)
      entry_for(photo, status: "processing", updated_at: 20.minutes.ago)

      described_class.new.perform

      expect(photo.reload.quota_refunded_at).to be_within(1.second).of(2.days.ago)
    end

    it "fails the meal and refunds after 3 resumes that did not settle it" do
      entry = entry_for(photo, status: "processing", updated_at: 20.minutes.ago)

      3.times do
        described_class.new.perform
        entry.update_columns(updated_at: 20.minutes.ago)
        expect(entry.reload.status).to eq("processing")
      end
      described_class.new.perform

      expect(entry.reload.status).to eq("failed")
      expect(FoodAi::Api).to have_received(:resume_analysis).exactly(3).times
      expect(photo.reload.quota_refunded_at).to be_present
    end

    it "a new analysis request starts the count again" do
      entry = entry_for(photo, status: "processing", updated_at: 20.minutes.ago)
      entry.update_columns(resume_attempts: 3, status: "failed")
      photo.update!(quota_refunded_at: Time.current)

      Nutrition::Api.request_analysis(user_id: user.id, food_entry_id: entry.id)

      expect(entry.reload).to have_attributes(status: "processing", resume_attempts: 0)
    end

    it "marks the meal failed when it has no photo" do
      entry = entry_for(photo, status: "processing", updated_at: 20.minutes.ago)
      entry.update_columns(photo_id: nil)

      described_class.new.perform

      expect(entry.reload.status).to eq("failed")
    end

    it "marks the meal failed when the last analysis ended in failure" do
      photo.update!(quota_refunded_at: Time.current)
      entry = entry_for(photo, status: "processing", updated_at: 20.minutes.ago)

      described_class.new.perform

      expect(entry.reload.status).to eq("failed")
    end

    it "a lost analyzed event: the meal is analyzed after the stuck routine and the outbox" do
      add_rice
      scripted(FoodAiAdapter::RICE)
      entry = entry_for(photo, status: "processing", updated_at: 20.minutes.ago)
      run_job(photo)
      Shared::Outbox::Event.where(name: "food_analysis.completed").delete_all

      described_class.new.perform
      run_publisher_now

      expect(entry.reload.status).to eq("analyzed")
    end

    it "keeps going when one meal fails to resume" do
      broken = entry_for(photo, status: "processing", updated_at: 20.minutes.ago)
      good_photo = create_photo(user:)
      good = entry_for(good_photo, status: "processing", updated_at: 20.minutes.ago)
      allow(FoodAi::Api).to receive(:resume_analysis).and_wrap_original do |original, **args|
        raise "boom" if args[:photo_id] == photo.id

        original.call(**args)
      end

      expect { described_class.new.perform }.not_to raise_error

      expect(FoodAi::AnalyzeJob).to have_received(:perform_async).with(good_photo.id)
      expect([ broken.reload.status, good.reload.status ]).to eq(%w[processing processing])
    end

    def add_rice
      FoodCatalog::CatalogItem.create!(source: "usda_fdc", source_version: "v1", source_item_id: SecureRandom.hex(3), license: "CC0-1.0", name: "rice",
                                       name_pt: "rice", kind: "ingredient", nutrients_per_100g: { "energy_kcal" => 130, "protein_g" => 2.7, "carbs_g" => 28, "fat_g" => 0.3 })
    end
  end
end

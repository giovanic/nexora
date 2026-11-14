require "rails_helper"
require "support/outbox_helpers"
require "support/food_ai_pipeline"

RSpec.describe "FoodAi retention routines" do
  include OutboxHelpers
  include FoodAiPipeline

  let(:user) { create_user }
  let(:prompt) { FoodAi::PromptCatalog.current }

  def analyzed_photo(days_ago:)
    photo = create_photo(user:)
    photo.update!(analyzed_at: days_ago.days.ago)
    photo
  end

  def analysis_for(photo, started_at: Time.current)
    FoodAi::AnalysisResult.create!(user_id: user.id, photo_id: photo.id, provider: "fake", model: "fake-1", prompt_version: prompt.version,
                                   schema_version: prompt.schema_version, status: "succeeded", raw_response: { "contains_food" => true },
                                   started_at:, created_at: started_at, updated_at: started_at)
  end

  describe FoodAi::PhotoRetentionJob do
    it "photo older than 30 days after analysis is deleted, the meal stays" do
      old = analyzed_photo(days_ago: 31)
      fresh = analyzed_photo(days_ago: 29)
      entry = Nutrition::FoodEntry.create!(id: old.food_entry_id, user_id: user.id, photo_id: old.id, source: "photo", status: "confirmed",
                                           client_request_id: SecureRandom.uuid, meal_at: Time.current, local_date: Date.current)

      described_class.new.perform

      expect(old.reload).to have_attributes(status: "deleted")
      expect(old.deleted_at).to be_present
      expect(FoodAi.storage.head(key: old.object_key)).to be_nil
      expect(Nutrition::FoodEntry.where(id: entry.id)).to exist
      expect(Nutrition::Api.entry(user_id: user.id, food_entry_id: entry.id).view[:photo_url]).to be_nil
      expect(fresh.reload.status).to eq("stored")
      expect(FoodAi.storage.head(key: fresh.object_key)).to be_present
    end

    it "keeps a photo that was never analyzed, however old" do
      waiting = create_photo(user:, status: "awaiting_upload")
      waiting.update!(created_at: 90.days.ago)

      described_class.new.perform

      expect(waiting.reload.status).to eq("awaiting_upload")
    end

    it "leaves the photo for the next run when storage fails, and does not stop the others" do
      failing = analyzed_photo(days_ago: 40)
      other = analyzed_photo(days_ago: 40)
      allow(FoodAi.storage).to receive(:delete).and_wrap_original do |original, key:|
        raise "storage down" if key == failing.object_key

        original.call(key:)
      end

      described_class.new.perform

      expect(failing.reload.status).to eq("stored")
      expect(other.reload.status).to eq("deleted")

      allow(FoodAi.storage).to receive(:delete).and_call_original
      described_class.new.perform

      expect(failing.reload.status).to eq("deleted")
      expect(FoodAi.storage.head(key: failing.object_key)).to be_nil
    end

    it "is safe to run again" do
      photo = analyzed_photo(days_ago: 31)

      2.times { described_class.new.perform }

      expect(photo.reload.status).to eq("deleted")
    end

    it "logs counts only" do
      photo = analyzed_photo(days_ago: 31)
      lines = []
      allow(Sidekiq.logger).to receive(:info) { |line| lines << line.to_s }

      described_class.new.perform

      expect(lines.join).to match(/food photo retention/)
      expect(lines.join).not_to include(photo.object_key, photo.id, user.id)
    end

    describe "the sweeper of deleted photos" do
      def deleted_photo(deleted_days_ago:)
        photo = create_photo(user:)
        photo.update!(status: "deleted", deleted_at: deleted_days_ago.days.ago)
        photo
      end

      it "deletes the object a failed purge left behind, and keeps the row for a week" do
        photo = deleted_photo(deleted_days_ago: 1)
        expect(FoodAi.storage.head(key: photo.object_key)).to be_present

        described_class.new.perform

        expect(FoodAi.storage.head(key: photo.object_key)).to be_nil
        expect(FoodAi::FoodPhoto.where(id: photo.id)).to exist
      end

      it "removes the row only after the object is gone and 7 days passed" do
        photo = deleted_photo(deleted_days_ago: 8)

        described_class.new.perform

        expect(FoodAi.storage.head(key: photo.object_key)).to be_nil
        expect(FoodAi::FoodPhoto.where(id: photo.id)).not_to exist
      end

      it "keeps the row, however old, while the object cannot be deleted" do
        photo = deleted_photo(deleted_days_ago: 30)
        allow(FoodAi.storage).to receive(:delete).and_raise("storage down")

        expect { described_class.new.perform }.not_to raise_error

        expect(FoodAi::FoodPhoto.where(id: photo.id)).to exist
        expect(FoodAi.storage.head(key: photo.object_key)).to be_present

        allow(FoodAi.storage).to receive(:delete).and_call_original
        described_class.new.perform

        expect(FoodAi::FoodPhoto.where(id: photo.id)).not_to exist
        expect(FoodAi.storage.head(key: photo.object_key)).to be_nil
      end
    end
  end

  describe FoodAi::AnalysisRetentionJob do
    it "analysis older than 90 days is deleted with raw_response" do
      old = analysis_for(create_photo(user:), started_at: 91.days.ago)
      fresh = analysis_for(create_photo(user:), started_at: 89.days.ago)

      described_class.new.perform

      expect(FoodAi::AnalysisResult.where(id: old.id)).not_to exist
      expect(FoodAi::AnalysisResult.find(fresh.id).raw_response).to be_present
    end

    it "usage older than 90 days loses the user link and keeps the cost" do
      old = FoodAi::UsageRecord.create!(user_id: user.id, provider: "fake", model: "fake-1", cost_usd: BigDecimal("0.5"), occurred_at: 91.days.ago)
      recent = FoodAi::UsageRecord.create!(user_id: user.id, provider: "fake", model: "fake-1", cost_usd: BigDecimal("0.25"), occurred_at: 10.days.ago)
      analysis = analysis_for(create_photo(user:), started_at: 95.days.ago)
      linked = FoodAi::UsageRecord.create!(user_id: user.id, analysis_id: analysis.id, provider: "fake", model: "fake-1", cost_usd: 1, occurred_at: 92.days.ago)

      2.times { described_class.new.perform }

      expect(old.reload).to have_attributes(user_id: nil, cost_usd: BigDecimal("0.5"))
      expect(linked.reload).to have_attributes(user_id: nil, analysis_id: nil, cost_usd: 1)
      expect(recent.reload.user_id).to eq(user.id)
    end
  end

  describe "FoodAi::Api.usage" do
    let(:other) { create_user }
    let(:from) { Time.utc(2026, 11, 1) }
    let(:to) { Time.utc(2026, 12, 1) }

    before do
      [ [ user, "0.10", Time.utc(2026, 11, 3) ], [ user, "0.20", Time.utc(2026, 11, 20) ], [ user, "0.40", Time.utc(2026, 10, 30) ],
        [ other, "1.00", Time.utc(2026, 11, 5) ], [ nil, "2.00", Time.utc(2026, 11, 6) ] ].each do |person, cost, at|
        FoodAi::UsageRecord.create!(user_id: person&.id, provider: "fake", model: "fake-1", cost_usd: BigDecimal(cost), occurred_at: at)
      end
    end

    it "usage can be summed per user and per period" do
      expect(FoodAi::Api.usage(user_id: user.id, from:, to:)).to eq(FoodAi::Api::UsageSummary.new(analyses: 2, cost_usd: BigDecimal("0.30")))
      expect(FoodAi::Api.usage(user_id: user.id, from: Time.utc(2026, 10, 1), to: from)).to have_attributes(analyses: 1, cost_usd: BigDecimal("0.40"))
    end

    it "sums everyone, unlinked records included, when no user is given" do
      expect(FoodAi::Api.usage(user_id: nil, from:, to:)).to have_attributes(analyses: 4, cost_usd: BigDecimal("3.30"))
    end

    it "is zero for a person without usage" do
      expect(FoodAi::Api.usage(user_id: create_user.id, from:, to:)).to have_attributes(analyses: 0, cost_usd: 0)
    end
  end
end

require "rails_helper"
require "support/outbox_helpers"
require "support/food_ai_pipeline"

RSpec.describe "FoodAi recovery and erasure of leftovers", :real_consumers do
  include OutboxHelpers
  include FoodAiPipeline

  let(:user) { create_user }
  let(:photo) { create_photo(user:) }
  let(:prompt) { FoodAi::PromptCatalog.current }

  before do
    use_operator_consent_version
    grant_food_photo_ai(user.id)
    allow(FoodAi::AnalyzeJob).to receive(:perform_async)
  end

  def resume(target = photo) = FoodAi::Api.resume_analysis(user_id: user.id, photo_id: target.id, food_entry_id: target.food_entry_id)

  def analysis_for(target, status:, updated_at: Time.current)
    FoodAi::AnalysisResult.create!(photo_id: target.id, user_id: user.id, food_entry_id: target.food_entry_id, provider: "fake", model: "fake-1",
                                   prompt_version: prompt.version, schema_version: prompt.schema_version, status:, started_at: updated_at,
                                   updated_at:, created_at: updated_at, finished_at: (updated_at unless status == "running"))
  end

  describe "FoodAi::Api.resume_analysis" do
    it "enqueues the job when the photo is stored and nothing ran" do
      expect(resume).to eq(:enqueued)

      expect(FoodAi::AnalyzeJob).to have_received(:perform_async).with(photo.id).once
    end

    it "enqueues the job to take over a stale running analysis" do
      analysis_for(photo, status: "running", updated_at: 11.minutes.ago)

      expect(resume).to eq(:enqueued)
      expect(FoodAi::AnalyzeJob).to have_received(:perform_async).with(photo.id)
    end

    it "leaves a fresh running analysis alone" do
      analysis_for(photo, status: "running", updated_at: 1.minute.ago)

      expect(resume).to eq(:running)
      expect(FoodAi::AnalyzeJob).not_to have_received(:perform_async)
    end

    it "republishes the completed event of a finished analysis whose event was lost" do
      analysis = analysis_for(photo, status: "succeeded")

      expect(resume).to eq(:republished)

      expect(completed_events).to eq([ { "analysis_id" => analysis.id, "food_entry_id" => photo.food_entry_id, "outcome" => "analyzed", "error_code" => nil } ])
      expect(FoodAi::AnalyzeJob).not_to have_received(:perform_async)
    end

    it "does not publish a second event while the first still waits in the outbox" do
      analysis_for(photo, status: "succeeded")

      2.times { resume }

      expect(completed_events.size).to eq(1)
    end

    it "republishes after the first event was delivered (the meal is still stuck)" do
      analysis_for(photo, status: "succeeded")
      resume
      run_publisher_now

      expect(resume).to eq(:republished)

      expect(completed_events.size).to eq(2)
    end

    it "republishes no_food of a photo already deleted" do
      analysis = analysis_for(photo, status: "no_food")
      photo.update!(status: "deleted", deleted_at: Time.current)

      expect(resume).to eq(:republished)
      expect(completed_events.sole).to include("analysis_id" => analysis.id, "outcome" => "no_food")
    end

    it "answers photo_missing when the photo is deleted without a result" do
      photo.update!(status: "deleted", deleted_at: Time.current)

      expect(resume).to have_attributes(code: "photo_missing")
    end

    it "answers photo_missing for an unknown photo and for another person's photo" do
      other = create_photo(user: create_user)

      expect(FoodAi::Api.resume_analysis(user_id: user.id, photo_id: other.id, food_entry_id: other.food_entry_id)).to have_attributes(code: "photo_missing")
      expect(FoodAi::Api.resume_analysis(user_id: user.id, photo_id: SecureRandom.uuid, food_entry_id: SecureRandom.uuid)).to have_attributes(code: "photo_missing")
      expect(resume(other)).to have_attributes(code: "photo_missing")
    end

    it "answers photo_missing for a photo of another meal" do
      expect(FoodAi::Api.resume_analysis(user_id: user.id, photo_id: photo.id, food_entry_id: SecureRandom.uuid)).to have_attributes(code: "photo_missing")
    end

    it "answers analysis_failed when the last run ended in failure" do
      analysis_for(photo, status: "failed")
      photo.update!(quota_refunded_at: Time.current)

      expect(resume).to have_attributes(code: "analysis_failed")
      expect(FoodAi::AnalyzeJob).not_to have_received(:perform_async)
    end

    it "resume twice makes one provider call" do
      allow(FoodAi::AnalyzeJob).to receive(:perform_async) { |id| run_job(FoodAi::FoodPhoto.find(id)) }
      adapter = scripted(FoodAiAdapter::RICE)
      allow(adapter).to receive(:analyze).and_call_original

      first = resume
      second = resume

      expect([ first, second ]).to eq(%i[enqueued republished])
      expect(adapter).to have_received(:analyze).once
      expect(FoodAi::AnalysisResult.where(photo_id: photo.id).count).to eq(1)
    end

    it "two jobs enqueued by two resumes still make one provider call" do
      adapter = scripted(FoodAiAdapter::RICE)
      allow(adapter).to receive(:analyze).and_call_original

      2.times { resume }
      2.times { run_job(photo) }

      expect(adapter).to have_received(:analyze).once
    end
  end

  describe "erasure of leftovers" do
    it "account erasure deletes the object of a photo already marked deleted" do
      pending_purge = create_photo(user:)
      pending_purge.update!(status: "deleted", deleted_at: Time.current)

      FoodAi::UserData.erase(user.id)

      expect(FoodAi.storage.head(key: pending_purge.object_key)).to be_nil
      expect(FoodAi::FoodPhoto.where(user_id: user.id)).to be_empty
    end

    it "account erasure keeps the rows when an object cannot be deleted, so the next try finds the key" do
      pending_purge = create_photo(user:)
      pending_purge.update!(status: "deleted", deleted_at: Time.current)
      allow(FoodAi.storage).to receive(:delete).and_raise("storage down")

      expect { FoodAi::UserData.erase(user.id) }.to raise_error(RuntimeError)

      expect(FoodAi::FoodPhoto.where(id: pending_purge.id)).to exist
    end

    it "erase_for_entry does not fail when the purge job cannot be enqueued" do
      allow(FoodAi.storage).to receive(:delete).and_raise("storage down")
      allow(FoodAi::PurgeObjectJob).to receive(:perform_async).and_raise(RedisClient::CannotConnectError, "redis down")
      lines = []
      allow(Rails.logger).to receive(:warn) { |line| lines << line.to_s }

      expect { FoodAi::Api.erase_for_entry(user_id: user.id, food_entry_id: photo.food_entry_id, photo_id: photo.id) }.not_to raise_error

      expect(photo.reload.status).to eq("deleted")
      expect(lines.join).to include(photo.id, "purge_enqueue_failed")
      expect(lines.join).not_to include(photo.object_key, "redis down")
    end
  end
end

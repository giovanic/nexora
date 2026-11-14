require "rails_helper"
require "support/outbox_helpers"
require "support/food_ai_pipeline"

RSpec.describe "FoodAi request_analysis and consent revocation", :real_consumers do
  include OutboxHelpers
  include FoodAiPipeline

  let(:user) { create_user }

  before do
    use_operator_consent_version
    grant_food_photo_ai(user.id)
    allow(FoodAi::AnalyzeJob).to receive(:perform_async)
    allow(FoodAi::PurgeObjectJob).to receive(:perform_async) { |id| FoodAi::PurgeObjectJob.new.perform(id) }
  end

  describe "FoodAi::Api.request_analysis" do
    let(:photo) { create_photo(user:, status: "awaiting_upload") }

    def request(photo: self.photo, user_id: user.id, food_entry_id: photo.food_entry_id)
      FoodAi::Api.request_analysis(user_id:, photo_id: photo.id, food_entry_id:)
    end

    it "marks the photo stored and enqueues the job" do
      expect(request).to eq(:enqueued)

      expect(photo.reload.status).to eq("stored")
      expect(FoodAi::AnalyzeJob).to have_received(:perform_async).with(photo.id)
    end

    it "ties a photo without a meal to the meal" do
      photo.update!(food_entry_id: nil)
      entry_id = SecureRandom.uuid

      expect(request(food_entry_id: entry_id)).to eq(:enqueued)

      expect(photo.reload.food_entry_id).to eq(entry_id)
    end

    it "not_uploaded when the object is not there" do
      gone = create_photo(user:, status: "awaiting_upload", store: false)

      expect(request(photo: gone)).to have_attributes(code: "not_uploaded")
      expect(FoodAi::AnalyzeJob).not_to have_received(:perform_async)
      expect(gone.reload.status).to eq("awaiting_upload")
    end

    it "invalid_photo when the size differs from the authorized one" do
      photo.update!(byte_size: photo.byte_size + 1)

      expect(request).to have_attributes(code: "invalid_photo", details: [ { field: "photo", code: "size_mismatch" } ])
    end

    it "invalid_photo when the type differs from the authorized one" do
      photo.update!(content_type: "image/png")

      expect(request).to have_attributes(code: "invalid_photo", details: [ { field: "photo", code: "type_mismatch" } ])
    end

    it "not_uploaded for another person's photo or a photo of another meal" do
      expect(request(user_id: create_user.id)).to have_attributes(code: "not_uploaded")
      expect(request(food_entry_id: SecureRandom.uuid)).to have_attributes(code: "not_uploaded")
    end

    it "consent_required without the consent" do
      Identity::Api.revoke_consent(user_id: user.id, purpose: "food_photo_ai")

      expect(request).to have_attributes(code: "consent_required")
      expect(FoodAi::AnalyzeJob).not_to have_received(:perform_async)
    end

    it "asking again for a failed photo counts its quota unit again" do
      photo.update!(status: "stored", quota_refunded_at: Time.current)

      expect(request).to eq(:enqueued)

      expect(photo.reload.quota_refunded_at).to be_nil
    end
  end

  describe "the consent.revoked consumer" do
    def revoke_and_deliver
      Identity::Api.revoke_consent(user_id: user.id, purpose: "food_photo_ai")
      run_publisher_now
    end

    it "deletes photos awaiting upload and stored, and tells their meals" do
      waiting = create_photo(user:, status: "awaiting_upload")
      stored = create_photo(user:)

      revoke_and_deliver

      expect([ waiting, stored ].map { |photo| photo.reload.status }).to eq(%w[deleted deleted])
      expect([ waiting, stored ].map { |photo| FoodAi.storage.head(key: photo.object_key) }).to eq([ nil, nil ])
      cancelled = completed_events.select { |event| event["outcome"] == "cancelled" }
      expect(cancelled.map { |event| event["food_entry_id"] }).to match_array([ waiting.food_entry_id, stored.food_entry_id ])
      expect(cancelled.map { |event| event["error_code"] }.uniq).to eq([ "consent_revoked" ])
    end

    it "cancels the run in progress" do
      stored = create_photo(user:)
      prompt = FoodAi::PromptCatalog.current
      running = FoodAi::AnalysisResult.create!(photo_id: stored.id, user_id: user.id, provider: "x", model: "y", prompt_version: prompt.version,
                                               schema_version: prompt.schema_version, status: "running", started_at: Time.current)

      revoke_and_deliver

      expect(running.reload).to have_attributes(status: "cancelled", error_code: "consent_revoked")
      expect(completed_events.sole).to include("analysis_id" => running.id, "outcome" => "cancelled")
    end

    it "keeps a photo whose analysis concluded" do
      scripted(FoodAiAdapter::RICE)
      done = create_photo(user:)
      run_job(done)

      revoke_and_deliver

      expect(done.reload.status).to eq("stored")
      expect(FoodAi.storage.head(key: done.object_key)).to be_present
      expect(completed_events.map { |event| event["outcome"] }).to eq([ "analyzed" ])
    end

    it "leaves another person's photo and other purposes alone" do
      other = create_photo(user: create_user)
      Identity::Api.grant_consent(user_id: user.id, purpose: "health_data", version: 1)

      Identity::Api.revoke_consent(user_id: user.id, purpose: "health_data")
      run_publisher_now
      Identity::Api.revoke_consent(user_id: user.id, purpose: "food_photo_ai")
      run_publisher_now

      expect(other.reload.status).to eq("stored")
    end

    it "is safe to deliver again" do
      create_photo(user:)
      revoke_and_deliver
      event = Shared::Outbox::Event.find_by!(name: "consent.revoked")

      expect { FoodAi::CancelOnRevocation.call(event) }.not_to(change { completed_events.size })
    end
  end
end

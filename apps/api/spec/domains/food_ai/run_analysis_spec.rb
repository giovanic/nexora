require "rails_helper"
require "support/identity_helpers"
require "support/outbox_helpers"
require "support/food_ai_pipeline"

RSpec.describe "FoodAi analysis pipeline" do
  include OutboxHelpers
  include FoodAiPipeline

  let(:user) { create_user }
  let(:photo) { create_photo(user:) }
  let(:prompt) { FoodAi::PromptCatalog.current }

  before do
    use_operator_consent_version
    grant_food_photo_ai(user.id)
  end

  def analyses = FoodAi::AnalysisResult.where(photo_id: photo.id).order(:started_at, :id)
  def outcome_of(event) = event.values_at("outcome", "error_code")

  describe "the stored object" do
    it "stored object is the normalized one, without EXIF" do
      scripted(FoodAiAdapter::RICE)
      before_bytes = FoodAi.storage.read(key: photo.object_key)
      expect(Vips::Image.new_from_buffer(before_bytes, "").get_typeof("exif-data")).not_to eq(0)

      run_job(photo)

      after = Vips::Image.new_from_buffer(FoodAi.storage.read(key: photo.object_key), "")
      expect(after.get_typeof("exif-data")).to eq(0)
      expect(after.get_fields.grep(/GPS/i)).to be_empty
      expect(photo.reload).to have_attributes(content_type: "image/jpeg", byte_size: FoodAi.storage.head(key: photo.object_key).byte_size)
    end

    it "sends the normalized bytes to the provider, not the original" do
      adapter = scripted(FoodAiAdapter::RICE)
      seen = nil
      allow(adapter).to receive(:analyze).and_wrap_original { |original, **args| seen = args[:image]; original.call(**args) }

      run_job(photo)

      expect(seen).to eq(FoodAi.storage.read(key: photo.object_key))
      expect(Vips::Image.new_from_buffer(seen, "").get_typeof("exif-data")).to eq(0)
    end
  end

  describe "a successful run" do
    it "analysis records prompt_version, schema_version, provider, model, tokens and cost" do
      scripted(FoodAiAdapter::RICE, provider: "anthropic", model: "claude-haiku-5-5", input_tokens: 2350, output_tokens: 800, cost_usd: BigDecimal("0.00125"))

      run_job(photo)

      analysis = analyses.sole
      expect(analysis).to have_attributes(status: "succeeded", prompt_version: prompt.version, schema_version: prompt.schema_version,
                                          provider: "anthropic", model: "claude-haiku-5-5", user_id: user.id, food_entry_id: photo.food_entry_id)
      expect(analysis.finished_at).to be_present
      usage = FoodAi::UsageRecord.sole
      expect(usage).to have_attributes(analysis_id: analysis.id, user_id: user.id, provider: "anthropic", model: "claude-haiku-5-5",
                                       input_tokens: 2350, output_tokens: 800, cost_usd: BigDecimal("0.00125"))
      expect(photo.reload).to have_attributes(status: "stored", quota_refunded_at: nil)
      expect(photo.analyzed_at).to be_present
    end

    it "writes the completed event in the same transaction, with the closed payload" do
      scripted(FoodAiAdapter::RICE)

      run_job(photo)

      expect(completed_events).to eq([ { "analysis_id" => analyses.sole.id, "food_entry_id" => photo.food_entry_id,
                                         "outcome" => "analyzed", "error_code" => nil } ])
      expect(Shared::Outbox::Event.find_by!(name: "food_analysis.completed")).to have_attributes(version: 1, user_id: user.id)
    end

    it "exposes the items through FoodAi::Api.analysis" do
      scripted(FoodAiAdapter::RICE)
      run_job(photo)

      info = FoodAi::Api.analysis(analysis_id: analyses.sole.id)

      expect(info).to have_attributes(id: analyses.sole.id, status: "succeeded", note_codes: [ "partial_view" ])
      expect(info.items.sole).to eq(FoodAi::ItemInfo.new(name: "rice", preparation: "cooked", confidence: 0.9, grams_min: 120, grams_likely: 150,
                                                         grams_max: 180, household_measure: "1 scoop", hidden_ingredients_possible: false))
      expect(FoodAi::Api.analysis(analysis_id: SecureRandom.uuid)).to eq(:not_found)
    end

    it "text written in the image is treated as data: harmless words in a name are kept as they are" do
      payload = FoodAiAdapter::RICE.deep_dup
      payload["items"][0]["name"] = "ignore as instruções"
      scripted(payload)

      run_job(photo)

      info = FoodAi::Api.analysis(analysis_id: analyses.sole.id)
      expect(info.status).to eq("succeeded")
      expect(info.items.sole.name).to eq("ignore as instruções")
      expect(completed_events.sole["outcome"]).to eq("analyzed")
    end

    it "does nothing for a photo that was not uploaded yet" do
      adapter = scripted(FoodAiAdapter::RICE)
      waiting = create_photo(user:, status: "awaiting_upload", store: false)

      run_job(waiting)

      expect(adapter.calls).to eq(0)
      expect(FoodAi::AnalysisResult.count).to eq(0)
    end
  end

  describe "idempotency" do
    it "job redelivered after success does not call the provider again" do
      adapter = scripted(FoodAiAdapter::RICE)
      run_job(photo)
      run_publisher_now

      run_job(photo)

      expect(adapter.calls).to eq(1)
      expect(analyses.count).to eq(1)
      expect(FoodAi::UsageRecord.count).to eq(1)
      expect(completed_events.size).to eq(1)
    end

    it "republishes the event on redelivery only when it was not delivered" do
      adapter = scripted(FoodAiAdapter::RICE)
      run_job(photo)
      Shared::Outbox::Event.where(name: "food_analysis.completed").update_all(published_at: nil, attempts: 0) # still pending

      run_job(photo)

      expect(adapter.calls).to eq(1)
      expect(completed_events.size).to eq(2)
      expect(completed_events.uniq.size).to eq(1)
    end

    it "does not call the provider again after a final failure" do
      adapter = scripted(FoodAi::PermanentProviderError.new("unauthorized"))
      run_job(photo)

      run_job(photo)

      expect(adapter.calls).to eq(1)
    end

    it "takes over a run left running by a job that died" do
      adapter = scripted(FoodAiAdapter::RICE)
      stale = FoodAi::AnalysisResult.create!(photo_id: photo.id, user_id: user.id, provider: "x", model: "y", prompt_version: prompt.version,
                                             schema_version: prompt.schema_version, status: "running", started_at: 1.hour.ago)
      stale.update_columns(updated_at: 1.hour.ago)

      run_job(photo)

      expect(adapter.calls).to eq(1)
      expect(stale.reload.status).to eq("failed")
      expect(analyses.pluck(:status)).to contain_exactly("failed", "succeeded")
    end

    it "first job finishes after its stale running row was taken over: late result discarded, cost kept, one result and one event" do
      adapter = scripted(FoodAiAdapter::RICE)
      nested = false
      allow(adapter).to receive(:analyze).and_wrap_original do |original, **args|
        unless nested
          nested = true
          analyses.update_all(updated_at: 1.hour.ago) # the first run looks dead, and a second job takes it over
          run_job(photo)
        end
        original.call(**args)
      end

      run_job(photo)

      expect(analyses.pluck(:status)).to contain_exactly("failed", "succeeded")
      expect(FoodAi::UsageRecord.count).to eq(2)
      expect(FoodAi::UsageRecord.pluck(:analysis_id)).to match_array(analyses.pluck(:id))
      expect(completed_events.map { |event| event["outcome"] }).to eq([ "analyzed" ])
      expect(photo.reload.quota_refunded_at).to be_nil
    end

    it "give_up after an analysis that succeeded neither fails nor refunds the photo" do
      scripted(FoodAiAdapter::RICE)
      run_job(photo)
      allow_any_instance_of(FoodAi::RunAnalysis).to receive(:republish).and_raise(RuntimeError)
      expect { run_job(photo) }.to raise_error(RuntimeError) # the redelivery fails after success, and Sidekiq runs out of retries

      FoodAi::RunAnalysis.give_up(photo_id: photo.id)

      expect(analyses.sole.status).to eq("succeeded")
      expect(photo.reload.quota_refunded_at).to be_nil
      expect(completed_events.map { |event| event["outcome"] }).to eq([ "analyzed" ])
    end

    it "give_up leaves a fresh running run of another job alone" do
      prompt = FoodAi::PromptCatalog.current
      FoodAi::AnalysisResult.create!(photo_id: photo.id, user_id: user.id, provider: "x", model: "y", prompt_version: prompt.version,
                                     schema_version: prompt.schema_version, status: "running", started_at: Time.current)

      FoodAi::RunAnalysis.give_up(photo_id: photo.id)

      expect(photo.reload.quota_refunded_at).to be_nil
      expect(completed_events).to be_empty
    end

    it "leaves a fresh running run alone" do
      adapter = scripted(FoodAiAdapter::RICE)
      FoodAi::AnalysisResult.create!(photo_id: photo.id, user_id: user.id, provider: "x", model: "y", prompt_version: prompt.version,
                                     schema_version: prompt.schema_version, status: "running", started_at: Time.current)

      run_job(photo)

      expect(adapter.calls).to eq(0)
    end
  end

  describe "failures" do
    it "transient errors retry three times, then failed with quota refunded" do
      adapter = scripted(FoodAi::TransientProviderError.new("timeout"))

      delays = run_until_settled(photo)

      expect(adapter.calls).to eq(3)
      expect(delays.size).to eq(2)
      expect(delays.first).to be > 0
      expect(delays.last).to be > delays.first
      expect(analyses.pluck(:status, :error_code).uniq).to eq([ %w[failed timeout] ])
      expect(photo.reload.quota_refunded_at).to be_present
      expect(completed_events).to eq([ { "analysis_id" => analyses.last.id, "food_entry_id" => photo.food_entry_id,
                                         "outcome" => "failed", "error_code" => "timeout" } ])
    end

    it "does not refund the quota while attempts remain" do
      scripted(FoodAi::TransientProviderError.new("rate_limited"), FoodAiAdapter::RICE)

      run_until_settled(photo)

      expect(photo.reload.quota_refunded_at).to be_nil
      expect(analyses.pluck(:status)).to eq(%w[failed succeeded])
      expect(completed_events.map { |e| e["outcome"] }).to eq([ "analyzed" ])
    end

    it "invalid output retries once, then failed" do
      adapter = scripted(FoodAiAdapter::RICE.merge("contains_food" => "yes"))

      delays = run_until_settled(photo)

      expect(adapter.calls).to eq(2)
      expect(delays.size).to eq(1)
      expect(analyses.pluck(:status, :error_code).uniq).to eq([ %w[failed wrong_type] ])
      expect(FoodAi::UsageRecord.count).to eq(2) # both answers were paid for
      expect(photo.reload.quota_refunded_at).to be_present
      expect(completed_events.sole).to include("outcome" => "failed", "error_code" => "wrong_type")
    end

    it "a refusal raised by the adapter also retries once" do
      adapter = scripted(FoodAi::InvalidOutputError.new("refusal"))

      run_until_settled(photo)

      expect(adapter.calls).to eq(2)
      expect(completed_events.sole).to include("outcome" => "failed", "error_code" => "refusal")
    end

    it "a permanent error fails at once and refunds" do
      adapter = scripted(FoodAi::PermanentProviderError.new("unauthorized"))

      delays = run_until_settled(photo)

      expect(adapter.calls).to eq(1)
      expect(delays).to be_empty
      expect(photo.reload.quota_refunded_at).to be_present
      expect(completed_events.sole).to include("outcome" => "failed", "error_code" => "unauthorized")
    end

    it "an unsupported photo fails without calling the provider" do
      adapter = scripted(FoodAiAdapter::RICE)
      bad = create_photo(user:, bytes: ImageFixtures.text_named_jpg)

      run_job(bad)

      expect(adapter.calls).to eq(0)
      expect(FoodAi::UsageRecord.count).to eq(0)
      expect(bad.reload.quota_refunded_at).to be_present
      # the original has EXIF and was never normalized: it goes now, like a photo with no food
      expect(bad.status).to eq("deleted")
      expect(FoodAi.storage.head(key: bad.object_key)).to be_nil
      expect(completed_events.sole).to include("outcome" => "failed", "error_code" => "invalid_photo")
    end

    it "a missing object fails with photo_missing" do
      adapter = scripted(FoodAiAdapter::RICE)
      missing = create_photo(user:, store: false)

      run_job(missing)

      expect(adapter.calls).to eq(0)
      expect(completed_events.sole).to include("outcome" => "failed", "error_code" => "photo_missing")
    end

    it "an unexpected error frees the run and is raised for Sidekiq to retry" do
      scripted(FoodAiAdapter::RICE)
      allow(FoodAi::ValidateOutput).to receive(:call).and_raise(RuntimeError, "boom")

      expect { run_job(photo) }.to raise_error(RuntimeError)

      expect(analyses.sole).to have_attributes(status: "failed", error_code: "internal_error")
      expect(completed_events).to be_empty
      expect(photo.reload.quota_refunded_at).to be_nil
    end

    it "gives up with a failed event when Sidekiq retries are exhausted" do
      FoodAi::RunAnalysis.give_up(photo_id: photo.id)

      expect(photo.reload.quota_refunded_at).to be_present
      expect(completed_events.sole).to include("outcome" => "failed", "error_code" => "internal_error")
    end
  end

  describe "no food and unreadable" do
    it "no food: no items, photo deleted, outcome no_food" do
      scripted(FoodAiAdapter::NO_FOOD)
      key = photo.object_key

      run_job(photo)

      expect(analyses.sole).to have_attributes(status: "no_food", raw_response: nil)
      expect(FoodAi::Api.analysis(analysis_id: analyses.sole.id)).to have_attributes(status: "no_food", items: [])
      expect(photo.reload).to have_attributes(status: "deleted")
      expect(photo.deleted_at).to be_present
      expect(FoodAi.storage.head(key:)).to be_nil
      expect(completed_events.sole).to include("outcome" => "no_food", "error_code" => nil)
      expect(photo.quota_refunded_at).to be_nil
    end

    it "image_quality unreadable is unreadable, with the photo deleted" do
      scripted(FoodAiAdapter::NO_FOOD.merge("image_quality" => "unreadable"))

      run_job(photo)

      expect(analyses.sole.status).to eq("unreadable")
      expect(FoodAi.storage.head(key: photo.object_key)).to be_nil
      expect(completed_events.sole["outcome"]).to eq("unreadable")
    end

    it "contains_food true with zero items is unreadable" do
      scripted(FoodAiAdapter::EMPTY_FOOD)

      run_job(photo)

      expect(analyses.sole).to have_attributes(status: "unreadable", raw_response: nil)
      expect(photo.reload.status).to eq("deleted")
      expect(FoodAi.storage.head(key: photo.object_key)).to be_nil
      expect(completed_events.sole["outcome"]).to eq("unreadable")
    end

    it "keeps no result for the analysis to read items from" do
      scripted(FoodAiAdapter::EMPTY_FOOD)
      run_job(photo)

      expect(FoodAi::Api.analysis(analysis_id: analyses.sole.id).items).to eq([])
    end
  end

  describe "consent revoked" do
    it "consent revoked before the call: provider never called, photo deleted, outcome cancelled" do
      adapter = scripted(FoodAiAdapter::RICE)
      Identity::Api.revoke_consent(user_id: user.id, purpose: "food_photo_ai")

      run_job(photo)

      expect(adapter.calls).to eq(0)
      expect(analyses.sole).to have_attributes(status: "cancelled", error_code: "consent_revoked")
      expect(photo.reload.status).to eq("deleted")
      expect(FoodAi.storage.head(key: photo.object_key)).to be_nil
      expect(completed_events.sole).to include("outcome" => "cancelled", "error_code" => "consent_revoked")
    end

    it "consent revoked during the call: result discarded" do
      adapter = scripted(FoodAiAdapter::RICE)
      allow(adapter).to receive(:analyze).and_wrap_original do |original, **args|
        Identity::Api.revoke_consent(user_id: user.id, purpose: "food_photo_ai")
        original.call(**args)
      end

      run_job(photo)

      expect(analyses.sole).to have_attributes(status: "cancelled", error_code: "consent_revoked", raw_response: nil)
      expect(FoodAi::Api.analysis(analysis_id: analyses.sole.id).items).to eq([])
      expect(photo.reload.status).to eq("deleted")
      expect(FoodAi.storage.head(key: photo.object_key)).to be_nil
      expect(FoodAi::UsageRecord.sole.analysis_id).to eq(analyses.sole.id) # the call was paid for
      expect(completed_events.sole).to include("outcome" => "cancelled")
    end

    it "cancelling a photo whose object cannot be deleted queues the deletion again" do
      scripted(FoodAiAdapter::RICE)
      Identity::Api.revoke_consent(user_id: user.id, purpose: "food_photo_ai")
      allow(FoodAi.storage).to receive(:delete).and_raise(IOError)
      allow(FoodAi::PurgeObjectJob).to receive(:perform_async)

      run_job(photo)

      expect(FoodAi::PurgeObjectJob).to have_received(:perform_async).with(photo.id)
    end
  end

  describe "meal deleted during the call" do
    it "entry deleted during the call: nothing recreated, cost kept without analysis" do
      adapter = scripted(FoodAiAdapter::RICE)
      allow(adapter).to receive(:analyze).and_wrap_original do |original, **args|
        FoodAi::Api.erase_for_entry(user_id: user.id, food_entry_id: photo.food_entry_id)
        original.call(**args)
      end

      run_job(photo)

      expect(analyses).to be_empty
      expect(completed_events).to be_empty
      expect(photo.reload.status).to eq("deleted")
      expect(FoodAi.storage.head(key: photo.object_key)).to be_nil # the normalized copy written meanwhile is gone too
      expect(FoodAi::UsageRecord.sole).to have_attributes(analysis_id: nil, user_id: user.id, input_tokens: 1000)
    end
  end

  describe "shutdown of the worker" do
    it "frees the run when Sidekiq shuts down mid-call, and the redelivery analyzes the photo" do
      adapter = scripted(Sidekiq::Shutdown.new, FoodAiAdapter::RICE)

      expect { run_job(photo) }.to raise_error(Sidekiq::Shutdown)
      expect(analyses.sole).to have_attributes(status: "failed", error_code: "internal_error")

      run_job(photo)

      expect(adapter.calls).to eq(2)
      expect(analyses.pluck(:status)).to eq(%w[failed succeeded])
      expect(completed_events.sole).to include("outcome" => "analyzed")
    end
  end

  describe "cost of a received answer" do
    it "stays recorded when writing the result fails afterwards" do
      scripted(FoodAiAdapter::RICE)
      allow_any_instance_of(FoodAi::RunAnalysis).to receive(:complete).and_raise(RuntimeError, "boom")

      expect { run_job(photo) }.to raise_error(RuntimeError)

      expect(FoodAi::UsageRecord.sole).to have_attributes(user_id: user.id, input_tokens: 1000)
      expect(analyses.sole.status).to eq("failed")
    end
  end

  describe "consent inside the job" do
    def stub_newer_consent_version
      stub_const("Identity::ConsentTexts::CURRENT_VERSIONS", Identity::ConsentTexts::CURRENT_VERSIONS.merge("food_photo_ai" => FoodAiConsent::VERSION + 1))
    end

    def expect_cancelled(adapter)
      expect(adapter.calls).to eq(0)
      expect(analyses.sole).to have_attributes(status: "cancelled", error_code: "consent_revoked")
      expect(photo.reload.status).to eq("deleted")
      expect(FoodAi.storage.head(key: photo.object_key)).to be_nil
      expect(completed_events.sole).to include("outcome" => "cancelled", "error_code" => "consent_revoked")
    end

    it "an outdated consent version cancels the queued analysis" do
      adapter = scripted(FoodAiAdapter::RICE)
      stub_newer_consent_version

      run_job(photo)

      expect_cancelled(adapter)
    end

    it "a change of operator cancels the queued analysis" do
      adapter = scripted(FoodAiAdapter::RICE)
      configure_food_ai_env("FOOD_AI_OPERATOR" => "another-operator")

      run_job(photo)

      expect_cancelled(adapter)
    end

    it "a revoked health_data consent cancels the queued analysis" do
      adapter = scripted(FoodAiAdapter::RICE)
      Identity::Api.revoke_consent(user_id: user.id, purpose: "health_data")

      run_job(photo)

      expect_cancelled(adapter)
    end

    it "a consent that goes stale during the call discards the result" do
      adapter = scripted(FoodAiAdapter::RICE)
      allow(adapter).to receive(:analyze).and_wrap_original do |original, **args|
        stub_newer_consent_version
        original.call(**args)
      end

      run_job(photo)

      expect(analyses.sole).to have_attributes(status: "cancelled", raw_response: nil)
      expect(photo.reload.status).to eq("deleted")
    end
  end

  describe "account deletion and erased rows during the analysis" do
    it "deletes the object when the photo row is gone by the time the result arrives" do
      adapter = scripted(FoodAiAdapter::RICE)
      allow(adapter).to receive(:analyze).and_wrap_original do |original, **args|
        FoodAi::FoodPhoto.where(id: photo.id).delete_all
        original.call(**args)
      end

      run_job(photo)

      expect(FoodAi.storage.head(key: photo.object_key)).to be_nil
      expect(analyses).to be_empty
    end

    it "records the cost with no person when the photo row is gone" do
      adapter = scripted(FoodAiAdapter::RICE)
      allow(adapter).to receive(:analyze).and_wrap_original do |original, **args|
        FoodAi::FoodPhoto.where(id: photo.id).delete_all
        original.call(**args)
      end

      run_job(photo)

      expect(FoodAi::UsageRecord.sole).to have_attributes(user_id: nil, analysis_id: nil)
    end

    it "does not write the normalized copy nor call the provider when the photo was deleted after the claim" do
      adapter = scripted(FoodAiAdapter::RICE)
      photo # created (and its object written) before the spy
      allow(FoodAi.storage).to receive(:read).and_wrap_original do |original, **args|
        photo.update!(status: "deleted", deleted_at: Time.current)
        original.call(**args)
      end
      allow(FoodAi.storage).to receive(:write).and_call_original

      run_job(photo)

      expect(FoodAi.storage).not_to have_received(:write)
      expect(adapter.calls).to eq(0)
      expect(FoodAi.storage.head(key: photo.object_key)).to be_nil
    end

    it "cancels when the account deletion was requested, before any provider call" do
      adapter = scripted(FoodAiAdapter::RICE)
      Identity::Api.request_deletion(user_id: user.id, password: IdentityHelpers::PASSWORD)

      run_job(photo)

      expect(adapter.calls).to eq(0)
      expect(analyses.sole.status).to eq("cancelled")
      expect(photo.reload.status).to eq("deleted")
    end
  end

  describe "erase and discard" do
    it "erase_for_entry deletes the object, the photo and the analyses, and unlinks the cost" do
      scripted(FoodAiAdapter::RICE)
      run_job(photo)

      FoodAi::Api.erase_for_entry(user_id: user.id, food_entry_id: photo.food_entry_id)

      expect(analyses).to be_empty
      expect(photo.reload.status).to eq("deleted")
      expect(FoodAi.storage.head(key: photo.object_key)).to be_nil
      expect(FoodAi::UsageRecord.sole.analysis_id).to be_nil
    end

    it "erase_for_entry leaves another person's photo alone" do
      other = create_user
      theirs = create_photo(user: other)

      FoodAi::Api.erase_for_entry(user_id: user.id, food_entry_id: theirs.food_entry_id)

      expect(theirs.reload.status).to eq("stored")
      expect(FoodAi.storage.head(key: theirs.object_key)).to be_present
    end

    it "discard_photo deletes the object and the photo that has no analysis" do
      expect(FoodAi::Api.discard_photo(user_id: user.id, photo_id: photo.id)).to eq(:discarded)

      expect(photo.reload.status).to eq("deleted")
      expect(FoodAi.storage.head(key: photo.object_key)).to be_nil
    end

    it "discard_photo marks the photo deleted and queues the object again when storage fails, with no error" do
      allow(FoodAi.storage).to receive(:delete).and_raise(IOError)
      allow(FoodAi::PurgeObjectJob).to receive(:perform_async)

      expect(FoodAi::Api.discard_photo(user_id: user.id, photo_id: photo.id)).to eq(:discarded)

      expect(photo.reload.status).to eq("deleted")
      expect(FoodAi::PurgeObjectJob).to have_received(:perform_async).with(photo.id)
    end

    it "discard_photo refuses a photo with an analysis, and another person's photo" do
      scripted(FoodAiAdapter::RICE)
      run_job(photo)
      expect(FoodAi::Api.discard_photo(user_id: user.id, photo_id: photo.id)).to eq(:in_use)
      expect(FoodAi::Api.discard_photo(user_id: create_user.id, photo_id: photo.id)).to eq(:not_found)
    end
  end

  describe "concurrency" do
    self.use_transactional_tests = false

    before { photo }

    after { ActiveRecord::Base.connection.execute("TRUNCATE users, food_photos, food_analysis_results, ai_usage_records, outbox_events, consent_records, audit_events CASCADE") }

    it "two jobs for the same photo call the provider once" do
      inside = Queue.new
      release = Queue.new
      adapter = scripted(FoodAiAdapter::RICE)
      allow(adapter).to receive(:analyze).and_wrap_original do |original, **args|
        inside << true
        release.pop
        original.call(**args)
      end

      first = Thread.new { ActiveRecord::Base.connection_pool.with_connection { run_job(photo) } }
      inside.pop
      # The first job is inside the provider call and holds no lock; the second finds the run claimed.
      ActiveRecord::Base.connection_pool.with_connection { Thread.new { run_job(photo) }.join }
      release << true
      first.join

      expect(adapter.calls).to eq(1)
      expect(analyses.pluck(:status)).to eq([ "succeeded" ])
      expect(FoodAi::UsageRecord.count).to eq(1)
    end

    it "does not hold a database lock while the provider answers" do
      inside = Queue.new
      release = Queue.new
      adapter = scripted(FoodAiAdapter::RICE)
      allow(adapter).to receive(:analyze).and_wrap_original do |original, **args|
        inside << true
        release.pop
        original.call(**args)
      end

      job = Thread.new { ActiveRecord::Base.connection_pool.with_connection { run_job(photo) } }
      inside.pop
      locked = ActiveRecord::Base.connection_pool.with_connection do
        ActiveRecord::Base.transaction do
          ActiveRecord::Base.connection.execute("SET LOCAL lock_timeout = '300ms'")
          FoodAi::FoodPhoto.lock.find(photo.id)
          true
        end
      end
      release << true
      job.join

      expect(locked).to be(true)
    end
  end
end

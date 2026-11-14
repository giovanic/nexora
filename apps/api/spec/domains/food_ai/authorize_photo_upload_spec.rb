require "rails_helper"
require "support/food_ai_consent"

RSpec.describe "FoodAi::Api.authorize_photo_upload" do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { Identity::User.create!(email: "up-#{SecureRandom.hex(4)}@example.test", password: "senha-forte-123", adult_confirmed_at: Time.current) }
  let(:day_start) { Time.utc(2026, 11, 13) }
  let(:day_end) { Time.utc(2026, 11, 14) }

  # The local day above is 2026-11-13, so every example runs inside it.
  around { |example| travel_to(Time.utc(2026, 11, 13, 12)) { example.run } }

  def authorize(user_id: user.id, client_request_id: SecureRandom.uuid, content_type: "image/jpeg", byte_size: 1_000_000)
    FoodAi::Api.authorize_photo_upload(user_id:, client_request_id:, content_type:, byte_size:, day_start:, day_end:)
  end

  context "with consent to the configured operator" do
    before do
      use_operator_consent_version
      grant_food_photo_ai(user.id)
    end

    it "authorizes and signs Content-Type and Content-Length for 900 s" do
      result = authorize(content_type: "image/png", byte_size: 12_345)

      expect(result).to be_a(FoodAi::Api::UploadAuthorization)
      expect(result.upload_headers).to eq("Content-Type" => "image/png", "Content-Length" => "12345")
      expect(result.expires_at).to eq(Time.utc(2026, 11, 13, 12, 15))
      expect(result.upload_url).to start_with("memory://upload/food-photos/")
    end

    it "gives the object a random key with no user id" do
      result = authorize
      photo = FoodAi::FoodPhoto.find(result.photo_id)

      expect(photo.object_key).to match(%r{\Afood-photos/\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z})
      expect(photo.object_key).not_to include(user.id)
      expect(photo).to have_attributes(status: "awaiting_upload", content_type: "image/jpeg", byte_size: 1_000_000)
    end

    it "authorizes image/heic and image/heif" do
      expect(authorize(content_type: "image/heic", client_request_id: "heic-1")).to be_ok
      expect(authorize(content_type: "image/heif", client_request_id: "heif-1")).to be_ok
      expect(FoodAi::FoodPhoto.pluck(:content_type)).to contain_exactly("image/heic", "image/heif")
    end

    it "refuses image/gif as unsupported_media_type" do
      expect(authorize(content_type: "image/gif")).to have_attributes(code: "unsupported_media_type")
      expect(FoodAi::FoodPhoto.count).to eq(0)
    end

    it "refuses a byte_size above 10 MB, zero or not an integer" do
      expect(authorize(byte_size: (10 * 1024 * 1024) + 1)).to have_attributes(code: "validation_failed", details: [ { field: "byte_size", code: "too_large" } ])
      expect(authorize(byte_size: 0)).to have_attributes(code: "validation_failed")
      expect(authorize(byte_size: "10")).to have_attributes(code: "validation_failed")
      expect(authorize(byte_size: 10 * 1024 * 1024)).to be_ok
    end

    it "returns the same photo and counts once for the same client_request_id" do
      first = authorize(client_request_id: "req-1")
      second = authorize(client_request_id: "req-1")

      expect(second.photo_id).to eq(first.photo_id)
      expect(FoodAi::FoodPhoto.where(user_id: user.id).count).to eq(1)
    end

    it "does not reissue a URL for a photo that is no longer awaiting upload, and counts once" do
      first = authorize(client_request_id: "req-1")
      FoodAi::FoodPhoto.find(first.photo_id).update!(status: "stored")

      again = authorize(client_request_id: "req-1")

      expect(again).to be_ok
      expect(again).to have_attributes(photo_id: first.photo_id, upload_url: nil, upload_headers: nil, expires_at: nil)
      expect(FoodAi::FoodPhoto.where(user_id: user.id).count).to eq(1)
    end

    it "keeps one client_request_id per person" do
      other = Identity::User.create!(email: "o-#{SecureRandom.hex(4)}@example.test", password: "senha-forte-123", adult_confirmed_at: Time.current)
      grant_food_photo_ai(other.id)

      a = authorize(client_request_id: "same")
      b = authorize(user_id: other.id, client_request_id: "same")

      expect(a.photo_id).not_to eq(b.photo_id)
    end

    it "refuses the 21st authorization of the day, with the end of the day as retry_at" do
      20.times { expect(authorize).to be_ok }

      result = authorize

      expect(result).to have_attributes(code: "analysis_quota_exceeded", retry_at: day_end)
      expect(FoodAi::FoodPhoto.count).to eq(20)
    end

    it "does not count refunded photos nor those of other days" do
      19.times { authorize }
      FoodAi::FoodPhoto.create!(user_id: user.id, client_request_id: "old", object_key: "food-photos/old", content_type: "image/jpeg",
                                authorized_at: day_start - 1.second)
      FoodAi::FoodPhoto.create!(user_id: user.id, client_request_id: "ref", object_key: "food-photos/ref", content_type: "image/jpeg",
                                authorized_at: day_start + 1.hour, quota_refunded_at: Time.current)

      expect(authorize).to be_ok
      expect(authorize).to have_attributes(code: "analysis_quota_exceeded")
    end

    it "reads the daily quota from FOOD_AI_DAILY_QUOTA" do
      configure_food_ai_env("FOOD_AI_DAILY_QUOTA" => "2")
      2.times { authorize }

      expect(authorize).to have_attributes(code: "analysis_quota_exceeded")
    end

    it "does not count a repeated request against the quota, even at the limit" do
      19.times { authorize }
      last = authorize(client_request_id: "last")

      expect(authorize(client_request_id: "last").photo_id).to eq(last.photo_id)
    end
  end

  it "refuses without consent as consent_required" do
    use_operator_consent_version

    expect(authorize).to have_attributes(code: "consent_required")
    expect(FoodAi::FoodPhoto.count).to eq(0)
  end

  it "refuses a revoked consent as consent_required" do
    use_operator_consent_version
    grant_food_photo_ai(user.id)
    Identity::Api.revoke_consent(user_id: user.id, purpose: "food_photo_ai")

    expect(authorize).to have_attributes(code: "consent_required")
  end

  it "refuses with consent v1 as consent_operator_mismatch, since v1 names no operator" do
    Identity::Api.grant_consent(user_id: user.id, purpose: "food_photo_ai", version: 1)
    configure_food_ai_env("FOOD_AI_OPERATOR" => "test-operator", "FOOD_AI_REGION" => "test-region")

    expect(authorize).to have_attributes(code: "consent_operator_mismatch")
  end

  it "refuses an outdated acceptance as consent_operator_mismatch" do
    expect(Identity::Api.grant_consent(user_id: user.id, purpose: "food_photo_ai", version: 1)).to be_ok
    use_operator_consent_version

    expect(authorize).to have_attributes(code: "consent_operator_mismatch")
  end

  it "refuses when the configured operator or region changes" do
    use_operator_consent_version
    grant_food_photo_ai(user.id)
    configure_food_ai_env("FOOD_AI_OPERATOR" => "another-operator")
    expect(authorize).to have_attributes(code: "consent_operator_mismatch")

    configure_food_ai_env("FOOD_AI_OPERATOR" => FoodAiConsent::OPERATOR, "FOOD_AI_REGION" => "another-region")
    expect(authorize).to have_attributes(code: "consent_operator_mismatch")
  end

  it "refuses when no operator is configured" do
    use_operator_consent_version(configured_operator: nil, configured_region: nil)
    grant_food_photo_ai(user.id)

    expect(authorize).to have_attributes(code: "consent_operator_mismatch")
  end

  describe "concurrency" do
    self.use_transactional_tests = false

    after { ActiveRecord::Base.connection.execute("TRUNCATE users, food_photos, consent_records, outbox_events, audit_events CASCADE") }

    def race(count, **options)
      gate = Queue.new
      threads = count.times.map do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            gate.pop
            authorize(**options)
          end
        end
      end
      count.times { gate << true }
      threads.map(&:value)
    end

    it "creates one photo for two concurrent requests with the same client_request_id" do
      use_operator_consent_version
      grant_food_photo_ai(user.id)

      results = race(2, client_request_id: "race")

      expect(results).to all(be_ok)
      expect(results.map(&:photo_id).uniq.size).to eq(1)
      expect(FoodAi::FoodPhoto.where(user_id: user.id).count).to eq(1)
    end

    it "never lets concurrent requests pass the quota" do
      use_operator_consent_version
      grant_food_photo_ai(user.id)
      configure_food_ai_env("FOOD_AI_DAILY_QUOTA" => "2")

      results = race(3)

      expect(results.count(&:ok?)).to eq(2)
      expect(FoodAi::FoodPhoto.where(user_id: user.id).count).to eq(2)
    end
  end
end

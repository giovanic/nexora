require "rails_helper"
require "support/contract"
require "support/identity_helpers"
require "support/outbox_helpers"
require "support/food_ai_consent"

RSpec.describe "POST /api/v1/food_entries/uploads", :identity, :real_consumers do
  include OutboxHelpers

  let!(:token) { mobile_token }
  let(:user_id) { Identity::User.find_by!(email: "ana@example.test").id }

  before do
    run_publisher
    post "/api/v1/consents", params: { purpose: "health_data", version: 1 }, headers: bearer(token), as: :json
  end

  def grant(for_token = token, version: FoodAiConsent::VERSION)
    post "/api/v1/consents", params: { purpose: "food_photo_ai", version: }, headers: bearer(for_token), as: :json
  end

  def upload(headers: bearer(token), **overrides)
    body = { client_request_id: "req-1", content_type: "image/jpeg", byte_size: 500_000, meal_at: Time.current.iso8601 }.merge(overrides)
    post "/api/v1/food_entries/uploads", params: body, headers:, as: :json
  end

  def error_code = response.parsed_body.dig("error", "code")

  it "needs a session" do
    upload(headers: {})

    expect(response).to have_http_status(:unauthorized)
    expect_response_to_match_contract
  end

  it "403 consent_required without food_photo_ai" do
    use_operator_consent_version

    upload

    expect(response).to have_http_status(:forbidden)
    expect(error_code).to eq("consent_required")
    expect_response_to_match_contract
  end

  it "403 consent_operator_mismatch with consent v1" do
    post "/api/v1/consents", params: { purpose: "food_photo_ai", version: 1 }, headers: bearer(token), as: :json
    configure_food_ai_env("FOOD_AI_OPERATOR" => "test-operator", "FOOD_AI_REGION" => "test-region")

    upload

    expect(response).to have_http_status(:forbidden)
    expect(error_code).to eq("consent_operator_mismatch")
    expect_response_to_match_contract
  end

  context "with consent to the configured operator" do
    before do
      use_operator_consent_version
      grant
    end

    it "403 consent_operator_mismatch when the configured operator changes" do
      configure_food_ai_env("FOOD_AI_OPERATOR" => "another-operator")

      upload

      expect(response).to have_http_status(:forbidden)
      expect(error_code).to eq("consent_operator_mismatch")
    end

    it "201 for image/heic and image/heif" do
      upload(content_type: "image/heic", client_request_id: "heic-1")
      expect(response).to have_http_status(:created)
      expect_response_to_match_contract

      upload(content_type: "image/heif", client_request_id: "heif-1")
      expect(response).to have_http_status(:created)
      expect_response_to_match_contract
    end

    it "422 unsupported_media_type for image/gif" do
      upload(content_type: "image/gif")

      expect(response).to have_http_status(:unprocessable_content)
      expect(error_code).to eq("unsupported_media_type")
      expect_response_to_match_contract
    end

    it "422 for byte_size above 10 MB" do
      upload(byte_size: (10 * 1024 * 1024) + 1)

      expect(response).to have_http_status(:unprocessable_content)
      expect(error_code).to eq("validation_failed")
      expect_response_to_match_contract
    end

    it "422 for a missing client_request_id or a bad meal_at" do
      upload(client_request_id: nil)
      expect(response).to have_http_status(:unprocessable_content)
      expect(error_code).to eq("validation_failed")

      upload(meal_at: "yesterday")
      expect(response).to have_http_status(:unprocessable_content)
      expect_response_to_match_contract
    end

    it "URL expires in 900 s and signs Content-Type and Content-Length" do
      travel_to(Time.utc(2026, 11, 13, 12)) do
        upload(meal_at: Time.current.iso8601)

        expect(response).to have_http_status(:created)
        body = response.parsed_body
        expect(body["upload_headers"]).to eq("Content-Type" => "image/jpeg", "Content-Length" => "500000")
        expect(Time.iso8601(body["expires_at"])).to eq(Time.utc(2026, 11, 13, 12, 15))
        expect_response_to_match_contract
      end
    end

    it "object key has no user id" do
      upload

      photo = FoodAi::FoodPhoto.sole
      expect(photo.object_key).to match(%r{\Afood-photos/\h{8}-})
      expect(photo.object_key).not_to include(user_id)
      expect(response.parsed_body["upload_url"]).not_to include(user_id)
    end

    it "entry starts pending with local_date in the user's time zone" do
      # 23:30 in São Paulo (UTC-3) is already the next day in UTC.
      travel_to(Time.utc(2026, 11, 14, 2, 30)) do
        upload(meal_at: Time.current.iso8601)

        entry = Nutrition::FoodEntry.sole
        expect(response.parsed_body["food_entry_id"]).to eq(entry.id)
        expect(entry).to have_attributes(status: "pending", source: "photo", local_date: Date.new(2026, 11, 13), user_id:)
        expect(entry.photo_id).to eq(FoodAi::FoodPhoto.sole.id)
        expect(FoodAi::FoodPhoto.sole.food_entry_id).to eq(entry.id)
      end
    end

    it "same client_request_id returns the same entry and counts once" do
      upload
      first = response.parsed_body
      upload
      second = response.parsed_body

      expect(response).to have_http_status(:created)
      expect(second["food_entry_id"]).to eq(first["food_entry_id"])
      expect(Nutrition::FoodEntry.count).to eq(1)
      expect(FoodAi::FoodPhoto.count).to eq(1)
    end

    it "repeating the request after the upload returns the meal without a new URL, counted once" do
      upload
      first = response.parsed_body
      FoodAi::FoodPhoto.sole.update!(status: "stored")
      Nutrition::FoodEntry.sole.update!(status: "processing")

      upload

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq("food_entry_id" => first["food_entry_id"], "status" => "processing",
                                         "upload_url" => nil, "upload_headers" => nil, "expires_at" => nil)
      expect_response_to_match_contract
      expect(FoodAi::FoodPhoto.count).to eq(1)
      expect(Nutrition::FoodEntry.count).to eq(1)
    end

    it "21st upload of the local day gets 429 with Retry-After until local midnight" do
      # 23:30 in São Paulo: 30 minutes to local midnight.
      travel_to(Time.utc(2026, 11, 14, 2, 30)) do
        20.times { |index| upload(client_request_id: "req-#{index}", meal_at: Time.current.iso8601) }
        expect(response).to have_http_status(:created)

        upload(client_request_id: "req-21", meal_at: Time.current.iso8601)

        expect(response).to have_http_status(:too_many_requests)
        expect(error_code).to eq("analysis_quota_exceeded")
        expect(response.headers["Retry-After"]).to eq("1800")
        expect_response_to_match_contract
        expect(Nutrition::FoodEntry.count).to eq(20)
      end
    end

    it "the quota restarts at local midnight" do
      travel_to(Time.utc(2026, 11, 14, 2, 30)) do
        20.times { |index| upload(client_request_id: "req-#{index}", meal_at: Time.current.iso8601) }
      end
      travel_to(Time.utc(2026, 11, 14, 3, 1)) do
        upload(client_request_id: "next-day", meal_at: Time.current.iso8601)

        expect(response).to have_http_status(:created)
      end
    end

    it "another user's entry is 404" do
      upload
      entry_id = response.parsed_body["food_entry_id"]
      other_id = Identity::Api.register(email: "bia@example.test", password: IdentityHelpers::PASSWORD, adult_confirmed: true,
                                        time_zone: "America/Sao_Paulo", client: "mobile", device_label: nil, ip: nil).user_id

      expect(Nutrition::Api.entry(user_id: other_id, food_entry_id: entry_id)).to eq(:not_found)
      expect(Nutrition::Api.entry(user_id:, food_entry_id: entry_id)).to have_attributes(id: entry_id, status: "pending")
    end

    it "keeps the upload URL out of the filtered parameters of the logs" do
      filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

      expect(filter.filter("upload_url" => "https://bucket/secret", "upload_headers" => { "Content-Type" => "image/jpeg" }))
        .to include("upload_url" => "[FILTERED]")
    end

    it "response matches the contract" do
      upload

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.keys).to match_array(%w[food_entry_id status upload_url upload_headers expires_at])
      expect_response_to_match_contract
    end
  end

  it "uses UTC while the profile is pending" do
    use_operator_consent_version
    grant
    UserProfile::Profile.where(user_id:).delete_all

    travel_to(Time.utc(2026, 11, 14, 2, 30)) { upload(meal_at: Time.current.iso8601) }

    expect(Nutrition::FoodEntry.sole.local_date).to eq(Date.new(2026, 11, 14))
  end
end

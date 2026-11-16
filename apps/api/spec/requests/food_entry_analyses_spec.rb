require "rails_helper"
require "support/contract"
require "support/identity_helpers"
require "support/outbox_helpers"
require "support/food_ai_consent"
require "support/image_fixtures"

RSpec.describe "POST /api/v1/food_entries/{id}/analysis", :identity, :real_consumers do
  include OutboxHelpers

  let!(:token) { mobile_token }
  let(:user_id) { Identity::User.find_by!(email: "ana@example.test").id }
  let(:bytes) { ImageFixtures.jpeg }

  before do
    run_publisher
    use_operator_consent_version
    post "/api/v1/consents", params: { purpose: "health_data", version: 1 }, headers: bearer(token), as: :json
    post "/api/v1/consents", params: { purpose: "food_photo_ai", version: FoodAiConsent::VERSION }, headers: bearer(token), as: :json
    allow(FoodAi::AnalyzeJob).to receive(:perform_async)
  end

  def start_entry(headers: bearer(token), byte_size: bytes.bytesize, client_request_id: "req-1")
    post "/api/v1/food_entries/uploads", params: { client_request_id:, content_type: "image/jpeg", byte_size:, meal_at: Time.current.iso8601 },
                                         headers:, as: :json
    response.parsed_body["food_entry_id"]
  end

  def upload(entry_id)
    photo = FoodAi::FoodPhoto.find(Nutrition::FoodEntry.find(entry_id).photo_id)
    FoodAi.storage.write(key: photo.object_key, bytes:, content_type: "image/jpeg")
    photo
  end

  def analyze(entry_id, headers: bearer(token))
    post "/api/v1/food_entries/#{entry_id}/analysis", headers:, as: :json
  end

  def error_code = response.parsed_body.dig("error", "code")

  it "needs a session" do
    analyze(SecureRandom.uuid, headers: {})

    expect(response).to have_http_status(:unauthorized)
    expect_response_to_match_contract
  end

  it "202 moves the meal to processing and enqueues the job" do
    entry_id = start_entry
    photo = upload(entry_id)

    analyze(entry_id)

    expect(response).to have_http_status(:accepted)
    expect(response.parsed_body).to eq("food_entry_id" => entry_id, "status" => "processing")
    expect_response_to_match_contract
    expect(Nutrition::FoodEntry.find(entry_id).status).to eq("processing")
    expect(FoodAi::AnalyzeJob).to have_received(:perform_async).with(photo.id)
  end

  it "409 when the meal is already processing, and enqueues only once" do
    entry_id = start_entry
    upload(entry_id)
    analyze(entry_id)

    analyze(entry_id)

    expect(response).to have_http_status(:conflict)
    expect(error_code).to eq("entry_not_analyzable")
    expect_response_to_match_contract
    expect(FoodAi::AnalyzeJob).to have_received(:perform_async).once
  end

  it "accepts a failed meal again" do
    entry_id = start_entry
    upload(entry_id)
    Nutrition::FoodEntry.find(entry_id).update!(status: "failed")

    analyze(entry_id)

    expect(response).to have_http_status(:accepted)
  end

  it "409 analysis_retry_limit after the third request for the same photo, and the meal stays failed" do
    entry_id = start_entry
    photo = upload(entry_id)
    3.times do
      Nutrition::FoodEntry.find(entry_id).update!(status: "failed")
      photo.update!(quota_refunded_at: Time.current)
      analyze(entry_id)
      expect(response).to have_http_status(:accepted)
    end
    Nutrition::FoodEntry.find(entry_id).update!(status: "failed")
    photo.update!(quota_refunded_at: Time.current)

    analyze(entry_id)

    expect(response).to have_http_status(:conflict)
    expect(error_code).to eq("analysis_retry_limit")
    expect_response_to_match_contract
    expect(Nutrition::FoodEntry.find(entry_id).status).to eq("failed")
  end

  it "429 when one person asks for more than 10 analyses in a minute" do
    11.times { analyze(SecureRandom.uuid) }

    expect(response).to have_http_status(:too_many_requests)
    expect(response.headers["Retry-After"]).to be_present
    expect_response_to_match_contract
  end

  it "409 for a meal already analyzed or confirmed" do
    entry_id = start_entry
    upload(entry_id)
    Nutrition::FoodEntry.find(entry_id).update!(status: "analyzed")

    analyze(entry_id)

    expect(response).to have_http_status(:conflict)
  end

  it "404 for another person's meal and for an unknown one" do
    entry_id = start_entry
    upload(entry_id)
    other = mobile_token(email: "bia@example.test")
    post "/api/v1/consents", params: { purpose: "health_data", version: 1 }, headers: bearer(other), as: :json

    analyze(entry_id, headers: bearer(other))
    expect(response).to have_http_status(:not_found)
    expect_response_to_match_contract

    analyze(SecureRandom.uuid)
    expect(response).to have_http_status(:not_found)
    expect(Nutrition::FoodEntry.find(entry_id).status).to eq("pending")
  end

  it "422 not_uploaded when the object was never sent, and the meal stays pending" do
    entry_id = start_entry

    analyze(entry_id)

    expect(response).to have_http_status(:unprocessable_content)
    expect(error_code).to eq("not_uploaded")
    expect_response_to_match_contract
    expect(Nutrition::FoodEntry.find(entry_id).status).to eq("pending")
    expect(FoodAi::AnalyzeJob).not_to have_received(:perform_async)
  end

  it "422 invalid_photo when the object does not match what was authorized" do
    entry_id = start_entry(byte_size: bytes.bytesize + 10)
    upload(entry_id)

    analyze(entry_id)

    expect(response).to have_http_status(:unprocessable_content)
    expect(error_code).to eq("invalid_photo")
    expect(response.parsed_body.dig("error", "details")).to eq([ { "field" => "photo", "code" => "size_mismatch" } ])
    expect_response_to_match_contract
    expect(Nutrition::FoodEntry.find(entry_id).status).to eq("pending")
  end

  it "403 consent_required after the consent was revoked, and the meal stays pending" do
    entry_id = start_entry
    upload(entry_id)
    delete "/api/v1/consents/food_photo_ai", headers: bearer(token)

    analyze(entry_id)

    expect(response).to have_http_status(:forbidden)
    expect(error_code).to eq("consent_required")
    expect_response_to_match_contract
    expect(Nutrition::FoodEntry.find(entry_id).status).to eq("pending")
  end

  it "puts the meal back when enqueueing fails" do
    entry_id = start_entry
    upload(entry_id)
    allow(FoodAi::AnalyzeJob).to receive(:perform_async).and_raise(RedisClient::CannotConnectError)

    analyze(entry_id)

    expect(response).to have_http_status(:internal_server_error)
    expect(Nutrition::FoodEntry.find(entry_id).status).to eq("pending")
  end
end

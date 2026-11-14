require "rails_helper"
require "sentry/sidekiq/error_handler"
require "support/identity_helpers"
require "support/outbox_helpers"
require "support/food_ai_pipeline"

# AC-03-11: a photo analysis, in success, in failure and with an invalid output, leaves no object
# key, signed URL, item name, grams or model text in the application log (request lines included),
# in the job messages or in the error tracker.
RSpec.describe "food analysis logging", :identity, :real_consumers do
  include OutboxHelpers
  include FoodAiPipeline
  include SentryCapture

  let(:log_path) { Rails.root.join("log/test.log") }
  let(:secret_name) { "arroz-secreto-xyz" }
  let(:secret_measure) { "colher-secreta" }
  let(:secret_grams) { [ 1337.25, 1411.75, 1593.5 ] }
  let(:model_output) do
    FoodAiAdapter::RICE.deep_merge("items" => [ { "name" => secret_name, "preparation" => "grelhado-secreto", "confidence" => 0.9,
                                                  "hidden_ingredients_possible" => true,
                                                  "portion" => { "grams_min" => secret_grams[0], "grams_likely" => secret_grams[1],
                                                                 "grams_max" => secret_grams[2], "household_measure" => secret_measure } } ])
  end
  let(:bytes) { ImageFixtures.jpeg }
  let(:token) { mobile_token }
  let(:user_id) { Identity::User.find_by!(email: "ana@example.test").id }

  before do
    run_publisher
    use_operator_consent_version
    post "/api/v1/consents", params: { purpose: "health_data", version: 1 }, headers: bearer(token), as: :json
    post "/api/v1/consents", params: { purpose: "food_photo_ai", version: FoodAiConsent::VERSION }, headers: bearer(token), as: :json
    allow(FoodAi::AnalyzeJob).to receive(:perform_async)
  end

  def log_during
    offset = File.size(log_path)
    yield
    Rails.logger.flush if Rails.logger.respond_to?(:flush)
    File.binread(log_path, nil, offset).force_encoding("UTF-8")
  end

  # Starts a meal and asks for its analysis over HTTP (so the request lines are logged), then runs
  # the job and every retry it schedules. Returns [log text, strings that must stay out of it].
  def analyze_over_http(client_request_id)
    forbidden = []
    text = log_during do
      post "/api/v1/food_entries/uploads", params: { client_request_id:, content_type: "image/jpeg", byte_size: bytes.bytesize, meal_at: Time.current.iso8601 },
                                           headers: bearer(token), as: :json
      forbidden << response.parsed_body["upload_url"]
      entry = Nutrition::FoodEntry.find(response.parsed_body["food_entry_id"])
      photo = FoodAi::FoodPhoto.find(entry.photo_id)
      FoodAi.storage.write(key: photo.object_key, bytes:, content_type: "image/jpeg")
      forbidden.push(photo.object_key, photo.object_key.delete_prefix("food-photos/"), FoodAi.storage.presigned_get(key: photo.object_key))
      post "/api/v1/food_entries/#{entry.id}/analysis", headers: bearer(token), as: :json
      expect(response).to have_http_status(:accepted)
      run_until_settled(photo)
    end
    [ text, forbidden ]
  end

  def expect_clean(text, forbidden)
    leaks = forbidden + [ "X-Amz-", secret_name, secret_measure, "grelhado-secreto", "partial_view" ] + secret_grams.map(&:to_s)
    leaks.each { |value| expect(text).not_to include(value) }
    expect(text).to include("food analysis") # the run did log its own lines
    expect(serialized_events).to all(satisfy { |event| leaks.none? { |value| event.include?(value) } })
  end

  let(:serialized_events) { sentry_events.map { |event| event.to_json_compatible.to_json } }

  it "success, failure and InvalidOutputError leave no URL, key, item name, grams or model output in logs or Sentry events" do
    scripted(model_output)
    text, forbidden = analyze_over_http("log-success")
    expect(FoodAi::AnalysisResult.order(:created_at).last.status).to eq("succeeded")
    expect_clean(text, forbidden)

    scripted(FoodAi::TransientProviderError.new("timeout"))
    text, forbidden = analyze_over_http("log-transient")
    expect(FoodAi::AnalysisResult.order(:created_at).last).to have_attributes(status: "failed", error_code: "timeout")
    expect_clean(text, forbidden)

    invalid = model_output.merge("contains_food" => "sim #{secret_name}")
    scripted(invalid)
    text, forbidden = analyze_over_http("log-invalid")
    expect(FoodAi::AnalysisResult.order(:created_at).last).to have_attributes(status: "failed", error_code: "wrong_type")
    expect_clean(text, forbidden)
  end

  it "keeps the secrets out of an unexpected job error, in the log and in the error tracker" do
    scripted(model_output)
    allow(FoodAi::ValidateOutput).to receive(:call).and_raise(RuntimeError, "failed on #{secret_name} #{secret_grams.first}")
    photo = nil
    text = log_during do
      photo = create_photo(user: Identity::User.find(user_id))
      job = { "class" => "FoodAi::AnalyzeJob", "jid" => "jid-1", "args" => [ photo.id ], "correlation_id" => "corr-1" }
      begin
        run_job(photo)
      rescue RuntimeError => error
        Sentry::Sidekiq::ErrorHandler.new.call(error, { job: }, Sidekiq.default_configuration)
      end
    end

    expect(sentry_events.size).to eq(1)
    [ secret_name, secret_grams.first.to_s, photo.object_key ].each do |value|
      expect(text).not_to include(value)
      expect(serialized_events.first).not_to include(value)
    end
  end

  it "reports a provider error to the tracker by its code only" do
    scripted(FoodAi::TransientProviderError.new("rate_limited"))
    Sentry.capture_exception(FoodAi::TransientProviderError.new("rate_limited"))
    Sentry.capture_exception(FoodAi::InvalidOutputError.new("refusal"))

    expect(sentry_events.size).to eq(2)
    expect(serialized_events.join).not_to include(secret_name)
    expect(sentry_events.map { |event| event.exception.values.first.value }).to all(match(/\A[a-z_]*\z/).or(be_blank))
  end

  it "filters the keys that carry a photo from logged parameters" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    params = { "photo_key" => "k", "object_key" => "k", "upload_url" => "u", "X-Amz-Signature" => "s", "name" => "rice", "grams_min" => 1 }

    filtered = filter.filter(params)

    expect(filtered.except("grams_min").values.uniq).to eq([ "[FILTERED]" ])
  end
end

require "rails_helper"
require "sentry/test_helper"
require "sentry/sidekiq/error_handler"

RSpec.describe "error tracking", type: :request do
  include Sentry::TestHelper

  let(:serialized_events) { sentry_events.map { |event| event.to_json_compatible.to_json } }

  context "without a DSN" do
    it "does not start" do
      expect(Observability::ErrorTracking.start({})).to be(false)
      expect(Sentry.initialized?).to be(false)
    end

    it "does not start with a blank DSN" do
      expect(Observability::ErrorTracking.start("ERROR_TRACKING_DSN" => " ")).to be(false)
      expect(Sentry.initialized?).to be(false)
    end
  end

  context "with a DSN" do
    before do
      Observability::ErrorTracking.start("ERROR_TRACKING_DSN" => Sentry::TestHelper::DUMMY_DSN)
      setup_sentry_test
    end

    after do
      teardown_sentry_test
      Sentry.close
    end

    def provoke_request_error
      allow_any_instance_of(HealthController).to receive(:live).and_raise(RuntimeError, "failed for tok-secret-value")

      get "/health/live?email=person@example.test&token=tok-secret-value",
          headers: {
            "X-Correlation-Id" => "corr-sentry-1",
            "Authorization" => "Bearer auth-secret-value",
            "Cookie" => "session=cookie-secret-value"
          }
    end

    it "captures an unhandled request error, tagged with the correlation identifier" do
      provoke_request_error

      expect(response).to have_http_status(:internal_server_error)
      expect(sentry_events.size).to eq(1)
      expect(sentry_events.first.tags).to include(correlation_id: "corr-sentry-1")
      expect(sentry_events.first.exception.values.first.type).to eq("RuntimeError")
    end

    it "does not send personal data, secrets or the exception message" do
      provoke_request_error

      expect(serialized_events.size).to eq(1)
      %w[person@example.test tok-secret-value auth-secret-value cookie-secret-value].each do |value|
        expect(serialized_events.first).not_to include(value)
      end
    end

    it "does not send a user" do
      provoke_request_error

      expect(sentry_events.first.user).to be_empty
    end

    it "does not send this machine's name, paths or installed gems" do
      provoke_request_error

      event = sentry_events.first.to_json_compatible
      frames = event["exception"]["values"].flat_map { |single| single.dig("stacktrace", "frames") || [] }

      expect(event["server_name"]).to eq("api")
      expect(event["modules"]).to be_blank
      expect(frames).not_to be_empty
      expect(frames.filter_map { |frame| frame["abs_path"] }).to eq([])
    end

    it "keeps only known tags and contexts, and drops a custom fingerprint" do
      Sentry.set_tags(email: "person@example.test")
      Sentry.set_context("meal", { items: "rice-secret-item" })

      Sentry.capture_exception(RuntimeError.new("x"), fingerprint: [ "person@example.test" ])

      expect(serialized_events.first).not_to include("person@example.test")
      expect(serialized_events.first).not_to include("rice-secret-item")
    end

    it "does not use a URL as the transaction name" do
      event = Sentry.get_current_client.event_from_exception(RuntimeError.new("x"))
      event.transaction = "/users/person@example.test"
      event.transaction_info = { source: :url }

      Observability::ErrorScrubber.call(event, {})

      expect(event.transaction).to eq("unrouted")
    end

    it "keeps a controller as the transaction name" do
      event = Sentry.get_current_client.event_from_exception(RuntimeError.new("x"))
      event.transaction = "HealthController#live"
      event.transaction_info = { source: :view }

      Observability::ErrorScrubber.call(event, {})

      expect(event.transaction).to eq("HealthController#live")
    end

    it "drops performance events" do
      expect(Sentry.configuration.before_send_transaction.call(:event, {})).to be_nil
    end

    it "captures a job error without its arguments" do
      job = { "class" => "SmokeJob", "jid" => "jid-1", "args" => [ "arg-secret-value" ], "correlation_id" => "corr-job-1" }

      Sentry::Sidekiq::ErrorHandler.new.call(RuntimeError.new("failed for arg-secret-value"), { job: }, Sidekiq.default_configuration)

      expect(serialized_events.size).to eq(1)
      expect(serialized_events.first).not_to include("arg-secret-value")
      expect(sentry_events.first.tags).to include(correlation_id: "corr-job-1")
    end

    it "captures the provoked error route" do
      post "/internal/smoke_errors"

      expect(response).to have_http_status(:internal_server_error)
      expect(sentry_events.first.exception.values.first.type).to eq("Internal::SmokeError")
    end
  end
end

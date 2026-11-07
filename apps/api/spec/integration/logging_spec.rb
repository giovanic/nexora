require "rails_helper"
require "support/sidekiq_process"

RSpec.describe "structured logging", type: :request do
  let(:log_path) { Rails.root.join("log/test.log") }

  # Reads the real log file, so the assertions cover the configured logger and
  # formatter instead of a test double.
  def api_log_during
    offset = File.size(log_path)
    yield
    Rails.logger.flush if Rails.logger.respond_to?(:flush)
    File.binread(log_path, nil, offset).force_encoding("UTF-8")
  end

  def json_lines(text)
    text.lines.map(&:strip).reject(&:empty?).map { |line| JSON.parse(line) }
  end

  def wait_for_job_lines(log, attribute, value)
    Timeout.timeout(20, nil, "job log line not found") do
      loop do
        found = File.readlines(log.path).select { |line| line.start_with?("{") }.map { |line| JSON.parse(line) }
          .select { |line| line[attribute] == value || line.dig("context", attribute) == value }
        return found if found.any?

        sleep 0.1
      end
    end
  end

  it "writes every API log line as JSON, with the correlation identifier" do
    text = api_log_during do
      post "/internal/smoke_jobs", headers: { "X-Correlation-Id" => "corr-test-1" }
    end

    lines = json_lines(text)
    expect(lines).not_to be_empty
    expect(lines).to all(include("timestamp", "level"))

    request_line = lines.find { |line| line["path"] == "/internal/smoke_jobs" }
    expect(request_line).to include("correlation_id" => "corr-test-1", "status" => 202)
    expect(request_line).to include("request_id", "duration_ms")
    expect(response.headers["x-correlation-id"]).to eq("corr-test-1")
  end

  it "carries the correlation identifier from the request to the job" do
    SidekiqProcess.with do |log|
      post "/internal/smoke_jobs", headers: { "X-Correlation-Id" => "corr-test-2" }

      job_lines = wait_for_job_lines(log, "correlation_id", "corr-test-2")

      expect(job_lines.first.dig("context", "class")).to eq("SmokeJob")
    end
  end

  it "gives a job enqueued outside a request a generated identifier" do
    SidekiqProcess.with do |log|
      jid = SmokeJob.perform_async(SecureRandom.uuid)

      job_lines = wait_for_job_lines(log, "jid", jid)

      expect(job_lines.first["correlation_id"]).to be_present
    end
  end

  it "writes every Sidekiq process line as JSON" do
    SidekiqProcess.with do |log|
      jid = SmokeJob.perform_async(SecureRandom.uuid)
      wait_for_job_lines(log, "jid", jid)

      # Sidekiq prints this one line directly, without going through its logger.
      lines = File.readlines(log.path).map(&:strip).reject { |line| line.empty? || line == "Signal INFO not supported" }

      expect { lines.each { |line| JSON.parse(line) } }.not_to raise_error
    end
  end

  describe "sensitive data" do
    let(:sensitive_values) do
      [ "person@example.test", "tok-secret-value", "pw-secret-value", "photo-secret.jpg", "rice-secret-item", "987654" ]
    end

    it "keeps sensitive query parameters and body out of the log" do
      text = api_log_during do
        get "/health/live?email=person@example.test&token=tok-secret-value"
        post "/internal/smoke_jobs", params: {
          password: "pw-secret-value",
          photo_url: "https://storage.example.test/photo-secret.jpg",
          food_items: "rice-secret-item",
          calories: 987654
        }
      end

      expect(json_lines(text)).not_to be_empty
      sensitive_values.each { |value| expect(text).not_to include(value) }
    end

    it "keeps an exception message out of the log" do
      allow_any_instance_of(HealthController).to receive(:live).and_raise(RuntimeError, "failed for tok-secret-value")

      text = api_log_during { get "/health/live" }

      expect(text).not_to include("tok-secret-value")
      expect(json_lines(text).find { |line| line["path"] == "/health/live" }).to include("status" => 500, "error" => "RuntimeError")
    end
  end
end

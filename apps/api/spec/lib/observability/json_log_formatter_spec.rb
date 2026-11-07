require "rails_helper"
require "observability/json_log_formatter"

RSpec.describe Observability::JsonLogFormatter do
  subject(:formatter) { described_class.new }

  let(:time) { Time.utc(2026, 11, 6, 12, 0, 0) }

  def line(message)
    JSON.parse(formatter.call("INFO", time, nil, message))
  end

  it "writes one JSON object per line" do
    expect(formatter.call("INFO", time, nil, "hello")).to end_with("}\n")
    expect(line("hello")).to include("level" => "INFO", "message" => "hello", "timestamp" => "2026-11-06T12:00:00.000Z")
  end

  it "merges a structured message into the line" do
    expect(line(status: 200, duration_ms: 1.5)).to include("status" => 200, "duration_ms" => 1.5)
  end

  it "keeps a line break inside the message from splitting the line" do
    expect(formatter.call("INFO", time, nil, "one\ntwo").count("\n")).to eq(1)
  end

  it "does not fail on invalid UTF-8" do
    expect(line("bad \xFF byte")["message"]).to include("bad")
  end

  it "includes the current correlation identifier" do
    Observability::Correlation.with("corr-test-1") do
      expect(line("hello")).to include("correlation_id" => "corr-test-1")
    end
  end

  it "omits the correlation identifier when there is none" do
    expect(line("hello")).not_to have_key("correlation_id")
  end
end

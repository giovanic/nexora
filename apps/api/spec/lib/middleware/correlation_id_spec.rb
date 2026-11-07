require "rails_helper"
require "middleware/correlation_id"

RSpec.describe Middleware::CorrelationId do
  let(:seen) { [] }
  let(:app) do
    lambda do |_env|
      seen << Observability::Correlation.id
      [ 200, {}, [ "ok" ] ]
    end
  end
  let(:request) { Rack::MockRequest.new(described_class.new(app)) }

  def perform(header = nil)
    request.get("/", header ? { "HTTP_X_CORRELATION_ID" => header } : {})
  end

  it "keeps a valid incoming identifier and returns it" do
    response = perform("abc12345")

    expect(seen).to eq([ "abc12345" ])
    expect(response.headers["x-correlation-id"]).to eq("abc12345")
  end

  it "generates an identifier when none is sent" do
    response = perform

    expect(seen.first).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
    expect(response.headers["x-correlation-id"]).to eq(seen.first)
  end

  [
    [ "line break", "abc12345\nforged" ],
    [ "JSON", '{"x":1}' ],
    [ "10 KB", "a" * 10_240 ],
    [ "too short", "abc" ]
  ].each do |description, hostile|
    it "replaces a hostile identifier: #{description}" do
      response = perform(hostile)

      expect(seen.first).not_to eq(hostile)
      expect(seen.first).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
      expect(response.headers["x-correlation-id"]).to eq(seen.first)
    end
  end

  it "does not leak the identifier to the next request on the same thread" do
    perform("abc12345")

    expect(Observability::Correlation.id).to be_nil
  end
end

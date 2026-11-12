require "rails_helper"
require "support/contract"

RSpec.describe "contract and routes" do
  # Rails adds these on its own, and /internal only exists outside production.
  let(:outside_contract) { %r{\A/(rails|assets|internal)(/|\z)} }

  let(:routes) do
    Rails.application.routes.routes
      .map { |route| [ route.verb, route.path.spec.to_s ] }
      .reject { |verb, path| verb.empty? || path.empty? || path.match?(outside_contract) }
      .map { |verb, path| Contract.operation(verb, path) }
      .uniq
  end

  it "documents every public route, by method and path" do
    expect(routes - Contract.operations).to eq([])
  end

  it "does not document an operation that does not exist" do
    expect(Contract.operations - routes).to eq([])
  end

  it "compares Rails parameters with OpenAPI parameters" do
    expect(Contract.operation("GET", "/api/v1/sessions/:id(.:format)")).to eq("GET /api/v1/sessions/{id}")
  end
end

require "rails_helper"
require "support/contract"

RSpec.describe "contract and routes" do
  # Rails adds these on its own, and /internal only exists outside production.
  let(:outside_contract) { %r{\A/(rails|assets|internal)(/|\z)} }

  let(:routes) do
    Rails.application.routes.routes
      .map { |route| route.path.spec.to_s.delete_suffix("(.:format)") }
      .reject { |path| path.empty? || path.match?(outside_contract) }
      .uniq
  end

  it "documents every public route" do
    expect(routes - Contract.paths).to eq([])
  end

  it "does not document a route that does not exist" do
    expect(Contract.paths - routes).to eq([])
  end
end

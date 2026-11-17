require "rails_helper"

RSpec.describe FoodAi::Adapters::FakeAdapter do
  let(:args) { { image: "bytes", content_type: "image/jpeg", prompt: FoodAi::PromptCatalog.current, schema: {} } }

  it "is a provider adapter" do
    expect(described_class.ancestors).to include(FoodAi::Adapters::ProviderAdapter)
  end

  it "the base class is abstract" do
    expect { FoodAi::Adapters::ProviderAdapter.new.analyze(**args) }.to raise_error(NotImplementedError)
  end

  it "returns the configured payload as a ProviderResponse" do
    adapter = described_class.new(payload: { "contains_food" => false })

    response = adapter.analyze(**args)

    expect(response).to be_a(FoodAi::ProviderResponse)
    expect(response.payload).to eq({ "contains_food" => false })
    expect(response.provider).to eq("fake")
    expect(response.cost_usd).to be_a(BigDecimal)
    expect(adapter.calls).to eq(1)
  end

  it "raises the configured error" do
    adapter = described_class.new(error: FoodAi::TransientProviderError.new("timeout"))

    expect { adapter.analyze(**args) }.to raise_error(FoodAi::TransientProviderError)
    expect(adapter.calls).to eq(1)
  end

  it "needs a payload or an error" do
    expect { described_class.new }.to raise_error(ArgumentError)
  end
end

require "rails_helper"

RSpec.describe "FoodAi provider errors" do
  it "form a hierarchy under ProviderError" do
    expect(FoodAi::TransientProviderError.ancestors).to include(FoodAi::ProviderError)
    expect(FoodAi::PermanentProviderError.ancestors).to include(FoodAi::ProviderError)
    expect(FoodAi::InvalidOutputError.ancestors).to include(FoodAi::ProviderError)
  end

  it "carry only a code from a closed list, as code and message" do
    error = FoodAi::TransientProviderError.new("timeout")

    expect(error.code).to eq("timeout")
    expect(error.message).to eq("timeout")
  end

  it "refuse a code outside the closed list" do
    expect { FoodAi::TransientProviderError.new("raw model text") }.to raise_error(ArgumentError, "unknown code")
    expect { FoodAi::PermanentProviderError.new("timeout") }.to raise_error(ArgumentError)
    expect { FoodAi::InvalidOutputError.new("timeout") }.to raise_error(ArgumentError)
  end

  it "can be raised with the class and a code" do
    expect { raise FoodAi::InvalidOutputError, "refusal" }.to raise_error(FoodAi::InvalidOutputError) { |e| expect(e.code).to eq("refusal") }
  end
end

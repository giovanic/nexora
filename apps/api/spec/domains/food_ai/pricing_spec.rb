require "rails_helper"

RSpec.describe FoodAi::Pricing do
  def cost(provider, model, input, output, on: Date.new(2026, 11, 13))
    described_class.cost_usd(provider: provider, model: model, input_tokens: input, output_tokens: output, on: on)
  end

  it "records the date of the sources" do
    expect(described_class::SOURCE_DATE).to eq(Date.new(2026, 11, 13))
  end

  it "pricing for each candidate model matches the registered sources" do
    # USD per million tokens, input / output (docs/architecture/EXTERNAL_SOURCES.md, "Provedores de IA", 2026-11-13).
    expectations = {
      %w[anthropic claude-haiku-5-5] => %w[0.10 0.50],
      %w[anthropic claude-sonnet-5-5] => %w[2 10],
      %w[gemini gemini-3.8-flash] => %w[0.75 3.75],
      %w[gemini gemini-3.5-flash-lite] => %w[0.30 2.50],
      %w[openai gpt-6-luna] => %w[0.10 0.50],
      %w[openai gpt-6.1-terra] => %w[1 5]
    }

    expectations.each do |(provider, model), (input_price, output_price)|
      # 100k tokens, the edge of the Haiku short-prompt tier: a tenth of the per-MTok price.
      expect(cost(provider, model, 100_000, 0)).to eq(BigDecimal(input_price) / 10)
      expect(cost(provider, model, 0, 1_000_000)).to eq(BigDecimal(output_price))
    end
  end

  it "returns a BigDecimal with fractions of a cent" do
    result = cost("anthropic", "claude-haiku-5-5", 1_500, 300)

    expect(result).to be_a(BigDecimal)
    expect(result).to eq(BigDecimal("0.0003"))
  end

  it "prices Haiku above 100k prompt tokens at the higher tier" do
    expect(cost("anthropic", "claude-haiku-5-5", 100_000, 0)).to eq(BigDecimal("0.01"))
    expect(cost("anthropic", "claude-haiku-5-5", 100_001, 0)).to eq(BigDecimal("100001") * BigDecimal("0.50") / 1_000_000)
  end

  it "models the Gemini 3.8 Flash price change after 2026-12-31" do
    expect(cost("gemini", "gemini-3.8-flash", 1_000_000, 1_000_000, on: Date.new(2026, 12, 31))).to eq(BigDecimal("4.50"))
    expect(cost("gemini", "gemini-3.8-flash", 1_000_000, 1_000_000, on: Date.new(2027, 1, 1))).to eq(BigDecimal("9.00"))
  end

  it "raises for an unknown provider or model" do
    expect { cost("anthropic", "claude-unknown", 1, 1) }.to raise_error(FoodAi::Pricing::UnknownModelError)
    expect { cost("nope", "x", 1, 1) }.to raise_error(FoodAi::Pricing::UnknownModelError)
  end

  it "rejects negative tokens" do
    expect { cost("openai", "gpt-6-luna", -1, 0) }.to raise_error(ArgumentError)
  end
end

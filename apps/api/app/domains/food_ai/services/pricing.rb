require "bigdecimal"
require "date"

module FoodAi
  # Cost of a provider call from the tokens the provider returned. Prices are USD per
  # million tokens (input, output), taken from docs/architecture/EXTERNAL_SOURCES.md,
  # section "Provedores de IA". Re-check the sources before changing a number.
  module Pricing
    SOURCE_DATE = Date.new(2026, 11, 13)
    PER_TOKENS = 1_000_000
    LONG_PROMPT_TOKENS = 100_000

    class UnknownModelError < StandardError; end

    Price = Data.define(:input, :output)

    def self.price(input, output) = Price.new(input: BigDecimal(input), output: BigDecimal(output))

    # Each model lists tiers: [{ until: last day, prompt_up_to: tokens }, price]; the first
    # tier whose conditions hold wins, the last one has no condition.
    TABLE = {
      %w[anthropic claude-haiku-5-5] => [
        [ { prompt_up_to: LONG_PROMPT_TOKENS }, price("0.10", "0.50") ],
        [ {}, price("0.50", "2.50") ]
      ],
      %w[anthropic claude-sonnet-5-5] => [ [ {}, price("2", "10") ] ],
      %w[gemini gemini-3.8-flash] => [
        [ { until: Date.new(2026, 12, 31) }, price("0.75", "3.75") ],
        [ {}, price("1.50", "7.50") ]
      ],
      %w[gemini gemini-3.5-flash-lite] => [ [ {}, price("0.30", "2.50") ] ],
      %w[openai gpt-6-luna] => [ [ {}, price("0.10", "0.50") ] ],
      %w[openai gpt-6.1-terra] => [ [ {}, price("1", "5") ] ],
      # Groq list price on paid plans, from the sources of 2026-11-25 (the others are of SOURCE_DATE). The free plan
      # charges nothing, so on it the recorded cost is an upper bound. Groq lists the model as a preview.
      %w[groq qwen/qwen3.8-27b] => [ [ {}, price("0.80", "4.00") ] ]
    }.freeze

    # BigDecimal, exact: fractions of a cent are kept.
    def self.cost_usd(provider:, model:, input_tokens:, output_tokens:, on: Date.current)
      raise ArgumentError, "negative tokens" if input_tokens.negative? || output_tokens.negative?

      tiers = TABLE[[ provider.to_s, model.to_s ]] or raise UnknownModelError, "no price registered for #{provider}/#{model}"
      price = tiers.find { |conditions, _| applies?(conditions, input_tokens, on) }.last
      (BigDecimal(input_tokens) * price.input + BigDecimal(output_tokens) * price.output) / PER_TOKENS
    end

    def self.applies?(conditions, input_tokens, on)
      return false if conditions[:until] && on > conditions[:until]
      return false if conditions[:prompt_up_to] && input_tokens > conditions[:prompt_up_to]

      true
    end
    private_class_method :applies?
  end
end

require "bigdecimal"

module FoodAi
  module Adapters
    # Test double: answers with a fixed payload or raises a fixed error. No network.
    class FakeAdapter < ProviderAdapter
      attr_reader :calls

      def initialize(payload: nil, error: nil, provider: "fake", model: "fake-1", input_tokens: 1000, output_tokens: 200)
        raise ArgumentError, "payload or error is required" if payload.nil? && error.nil?

        super()
        @payload = payload
        @error = error
        @provider = provider
        @model = model
        @input_tokens = input_tokens
        @output_tokens = output_tokens
        @calls = 0
      end

      def analyze(image:, content_type:, prompt:, schema:)
        @calls += 1
        raise @error if @error

        ProviderResponse.new(payload: @payload, provider: @provider, model: @model, input_tokens: @input_tokens,
                             output_tokens: @output_tokens, cost_usd: BigDecimal("0"))
      end
    end
  end
end

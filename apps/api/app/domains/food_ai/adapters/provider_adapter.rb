module FoodAi
  module Adapters
    # Contract implemented by one adapter per AI provider (AI_ARCHITECTURE, "Interface do provedor").
    class ProviderAdapter
      # image: normalized bytes; content_type: their MIME type
      # prompt: FoodAi::Prompt; schema: output JSON Schema (the version the provider accepts)
      # Returns a FoodAi::ProviderResponse, or raises TransientProviderError,
      # PermanentProviderError or InvalidOutputError (code only, never provider text).
      def analyze(image:, content_type:, prompt:, schema:)
        raise NotImplementedError, "#{self.class.name} must implement analyze"
      end
    end
  end
end

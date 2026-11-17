module FoodAi
  module Adapters
    # Gemini API generateContent, image in inlineData, JSON answer through generationConfig.
    # The key goes in the x-goog-api-key header, never in the URL.
    class GeminiAdapter < HttpAdapter
      PROVIDER = "gemini".freeze
      BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models".freeze
      BLOCKED_FINISH_REASONS = %w[SAFETY PROHIBITED_CONTENT BLOCKLIST SPII RECITATION].freeze

      private

      def request(image:, content_type:, prompt:, schema:)
        url = "#{BASE_URL}/#{model}:generateContent"
        headers = { "x-goog-api-key" => api_key }
        body = {
          contents: [ {
            role: "user",
            parts: [
              { inlineData: { mimeType: content_type, data: base64(image) } },
              { text: prompt.body }
            ]
          } ],
          generationConfig: {
            responseMimeType: "application/json",
            responseJsonSchema: schema,
            maxOutputTokens: MAX_OUTPUT_TOKENS
          }
        }
        [ url, headers, body ]
      end

      def extract(parsed)
        raise InvalidOutputError, "refusal" if hash_or_empty(parsed["promptFeedback"])["blockReason"]

        candidate = hash_or_empty(Array(parsed["candidates"]).first)
        parts = Array(hash_or_empty(candidate["content"])["parts"])
        text = parts.filter_map { |part| part["text"] if part.is_a?(Hash) && !part["thought"] }.join
        raise InvalidOutputError, "refusal" if text.empty? && BLOCKED_FINISH_REASONS.include?(candidate["finishReason"])

        usage = hash_or_empty(parsed["usageMetadata"])
        thoughts = usage.key?("thoughtsTokenCount") ? tokens!(usage["thoughtsTokenCount"]) : 0
        # Thinking tokens are billed as output.
        [ text, tokens!(usage["promptTokenCount"]), tokens!(usage["candidatesTokenCount"]) + thoughts ]
      end
    end
  end
end

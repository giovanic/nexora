module FoodAi
  module Adapters
    # Anthropic Messages API, structured output in output_config.format (EXTERNAL_SOURCES,
    # "Provedores de IA"). Image inline in base64.
    class AnthropicAdapter < HttpAdapter
      PROVIDER = "anthropic".freeze
      URL = "https://api.anthropic.com/v1/messages".freeze
      API_VERSION = "2026-10-21".freeze

      private

      def request(image:, content_type:, prompt:, schema:)
        headers = { "x-api-key" => api_key, "anthropic-version" => API_VERSION }
        body = {
          model: model,
          max_tokens: MAX_OUTPUT_TOKENS,
          messages: [ {
            role: "user",
            content: [
              { type: "image", source: { type: "base64", media_type: content_type, data: base64(image) } },
              { type: "text", text: prompt.body }
            ]
          } ],
          output_config: { format: { type: "json_schema", schema: SchemaTransform.for_anthropic(schema) } }
        }
        [ URL, headers, body ]
      end

      def extract(parsed)
        raise InvalidOutputError, "refusal" if parsed["stop_reason"] == "refusal"

        block = Array(parsed["content"]).find { |item| item.is_a?(Hash) && item["type"] == "text" }
        usage = parsed["usage"].is_a?(Hash) ? parsed["usage"] : {}
        [ block && block["text"], usage["input_tokens"].to_i, usage["output_tokens"].to_i ]
      end
    end
  end
end

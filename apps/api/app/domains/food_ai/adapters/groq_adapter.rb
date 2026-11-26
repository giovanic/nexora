module FoodAi
  module Adapters
    # Groq's OpenAI-compatible Chat Completions with a strict json_schema (constrained decoding), image as a base64
    # data URL. Groq's services agreement forbids training on inputs or outputs, free plan included. It does not
    # retain inference data by default, but may log inputs and outputs for up to 30 days for troubleshooting or
    # abuse unless the account opts out or turns on Zero Data Retention in Data Controls, an account setting this
    # code cannot check (docs/architecture/EXTERNAL_SOURCES.md, "Provedores de IA", Groq).
    # Only vision models apply: Groq's openai/gpt-oss-120b reads text only, so it has no price and is refused.
    class GroqAdapter < HttpAdapter
      PROVIDER = "groq".freeze
      URL = "https://api.groq.com/openai/v1/chat/completions".freeze

      private

      def request(image:, content_type:, prompt:, schema:)
        headers = { "authorization" => "Bearer #{api_key}" }
        body = {
          model: model,
          max_completion_tokens: MAX_OUTPUT_TOKENS,
          messages: [ {
            role: "user",
            content: [
              { type: "text", text: prompt.body },
              { type: "image_url", image_url: { url: "data:#{content_type};base64,#{base64(image)}" } }
            ]
          } ],
          response_format: { type: "json_schema", json_schema: { name: "food_analysis", strict: true, schema: SchemaTransform.for_openai(schema) } }
        }
        [ URL, headers, body ]
      end

      def extract(parsed)
        choice = Array(parsed["choices"]).find { |item| item.is_a?(Hash) }
        message = hash_or_empty(choice && choice["message"])
        raise InvalidOutputError, "refusal" if message["refusal"].is_a?(String) && !message["refusal"].empty?

        usage = hash_or_empty(parsed["usage"])
        [ message["content"], tokens!(usage["prompt_tokens"]), tokens!(usage["completion_tokens"]) ]
      end
    end
  end
end

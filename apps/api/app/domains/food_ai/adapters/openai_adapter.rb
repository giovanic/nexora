module FoodAi
  module Adapters
    # OpenAI Responses API with a strict json_schema, store: false (nothing kept by the API),
    # image as a base64 data URL.
    class OpenaiAdapter < HttpAdapter
      PROVIDER = "openai".freeze
      URL = "https://api.openai.com/v1/responses".freeze

      private

      def request(image:, content_type:, prompt:, schema:)
        headers = { "authorization" => "Bearer #{api_key}" }
        body = {
          model: model,
          store: false,
          max_output_tokens: MAX_OUTPUT_TOKENS,
          input: [ {
            role: "user",
            content: [
              { type: "input_text", text: prompt.body },
              { type: "input_image", image_url: "data:#{content_type};base64,#{base64(image)}" }
            ]
          } ],
          text: { format: { type: "json_schema", name: "food_analysis", strict: true, schema: SchemaTransform.for_openai(schema) } }
        }
        [ URL, headers, body ]
      end

      def extract(parsed)
        contents = Array(parsed["output"]).select { |item| item.is_a?(Hash) && item["type"] == "message" }
                                          .flat_map { |item| Array(item["content"]) }.select { |item| item.is_a?(Hash) }
        raise InvalidOutputError, "refusal" if contents.any? { |item| item["type"] == "refusal" }

        text = contents.find { |item| item["type"] == "output_text" }&.dig("text")
        usage = parsed["usage"].is_a?(Hash) ? parsed["usage"] : {}
        [ text, usage["input_tokens"].to_i, usage["output_tokens"].to_i ]
      end
    end
  end
end

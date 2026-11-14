require "rails_helper"
require "json"

RSpec.describe "FoodAi HTTP adapters" do
  let(:api_key) { "sk-test-SECRET-KEY-123" }
  let(:image) { "\xFF\xD8\xFFfake-jpeg-bytes".b }
  let(:prompt) { FoodAi::PromptCatalog.current }
  let(:schema) { prompt.schema }
  let(:payload) do
    { "contains_food" => true, "image_quality" => "good", "note_codes" => [],
      "items" => [ { "name" => "arroz", "preparation" => "cozido", "confidence" => 0.9, "hidden_ingredients_possible" => false,
                     "portion" => { "grams_min" => 100, "grams_likely" => 150, "grams_max" => 200, "household_measure" => "1 concha" } } ] }
  end

  # Records what is sent and answers with the queued response (or raises the queued exception).
  let(:transport) do
    Class.new do
      attr_reader :calls

      def initialize = @calls = []
      def queue(answer) = (@answer = answer)

      def post_json(url:, headers:, body:, timeout: 45)
        @calls << { url: url, headers: headers, body: body, timeout: timeout }
        raise @answer if @answer.is_a?(Exception) || (@answer.is_a?(Class) && @answer < Exception)

        @answer
      end
    end.new
  end

  def reply(status, hash_or_text)
    body = hash_or_text.is_a?(String) ? hash_or_text : JSON.generate(hash_or_text)
    FoodAi::Adapters::HttpTransport::Response.new(status: status, body: body)
  end

  def analyze = adapter.analyze(image: image, content_type: "image/jpeg", prompt: prompt, schema: schema)

  shared_examples "an http adapter" do |provider:, model:, input_tokens:, output_tokens:|
    let(:adapter) { described_class.new(api_key: api_key, model: model, transport: transport) }

    before { transport.queue(ok_reply) }

    it "sends the image inline and never a URL or file id" do
      analyze
      json = JSON.generate(transport.calls.first[:body])

      expect(json).to include(Base64.strict_encode64(image))
      expect(json).not_to match(/"(file_id|file_uri|fileData)"/)
      expect(json).not_to match(%r{"(url|image_url)":"https?://})
    end

    it "request body has no name, e-mail or user id" do
      analyze
      json = JSON.generate(transport.calls.first[:body])

      expect(json).not_to match(/user_?id|food_entry|e-?mail|"user"\s*:\s*"/i)
      expect(json).not_to include("@")
    end

    it "parses the structured output and the token counts" do
      response = analyze

      expect(response).to be_a(FoodAi::ProviderResponse)
      expect(response.payload).to eq(payload)
      expect(response.provider).to eq(provider)
      expect(response.model).to eq(model)
      expect(response.input_tokens).to eq(input_tokens)
      expect(response.output_tokens).to eq(output_tokens)
      expect(response.cost_usd).to eq(FoodAi::Pricing.cost_usd(provider: provider, model: model, input_tokens: input_tokens, output_tokens: output_tokens))
    end

    it "posts with the 45 second timeout over https" do
      analyze

      expect(transport.calls.first[:timeout]).to eq(45)
      expect(transport.calls.first[:url]).to start_with("https://")
    end

    it "429 and 503 raise TransientProviderError" do
      transport.queue(reply(429, { error: "x" }))
      expect { analyze }.to raise_error(FoodAi::TransientProviderError) { |e| expect(e.code).to eq("rate_limited") }

      transport.queue(reply(503, { error: "x" }))
      expect { analyze }.to raise_error(FoodAi::TransientProviderError) { |e| expect(e.code).to eq("provider_unavailable") }
    end

    it "400 raises PermanentProviderError, and 401 and 404 have their own codes" do
      { 400 => "bad_request", 401 => "unauthorized", 404 => "model_unavailable" }.each do |status, code|
        transport.queue(reply(status, { error: "x" }))
        expect { analyze }.to raise_error(FoodAi::PermanentProviderError) { |e| expect(e.code).to eq(code) }
      end
    end

    it "timeouts and connection failures raise TransientProviderError" do
      [ Net::ReadTimeout, Net::OpenTimeout, Net::WriteTimeout ].each do |klass|
        transport.queue(klass)
        expect { analyze }.to raise_error(FoodAi::TransientProviderError) { |e| expect(e.code).to eq("timeout") }
      end
      transport.queue(Errno::ECONNREFUSED)
      expect { analyze }.to raise_error(FoodAi::TransientProviderError) { |e| expect(e.code).to eq("provider_unavailable") }
    end

    it "refusal or non-JSON raises InvalidOutputError" do
      transport.queue(refusal_reply)
      expect { analyze }.to raise_error(FoodAi::InvalidOutputError) { |e| expect(e.code).to eq("refusal") }

      transport.queue(non_json_reply)
      expect { analyze }.to raise_error(FoodAi::InvalidOutputError) { |e| expect(e.code).to eq("not_an_object") }

      transport.queue(reply(200, "<html>gateway</html>"))
      expect { analyze }.to raise_error(FoodAi::InvalidOutputError) { |e| expect(e.code).to eq("not_an_object") }
    end

    it "api key is not in the URL, the body or an error message" do
      analyze
      call = transport.calls.first

      expect(call[:url]).not_to include(api_key)
      expect(JSON.generate(call[:body])).not_to include(api_key)
      expect(call[:headers].values.join(" ")).to include(api_key)

      [ reply(400, "oops #{api_key}"), reply(500, "x"), reply(200, "not json #{api_key}"), refusal_reply ].each do |bad|
        transport.queue(bad)
        expect { analyze }.to raise_error(FoodAi::ProviderError) { |e| expect(e.message).not_to include(api_key) }
      end
    end

    it "an unpriced model is refused with a code" do
      other = described_class.new(api_key: api_key, model: "not-a-model", transport: transport)

      expect { other.analyze(image: image, content_type: "image/jpeg", prompt: prompt, schema: schema) }
        .to raise_error(FoodAi::PermanentProviderError) { |e| expect(e.code).to eq("unsupported_model") }
    end
  end

  describe FoodAi::Adapters::AnthropicAdapter do
    let(:ok_reply) do
      reply(200, { content: [ { type: "text", text: JSON.generate(payload) } ], stop_reason: "end_turn",
                   usage: { input_tokens: 1500, output_tokens: 300 } })
    end
    let(:refusal_reply) { reply(200, { content: [], stop_reason: "refusal", usage: { input_tokens: 10, output_tokens: 0 } }) }
    let(:non_json_reply) { reply(200, { content: [ { type: "text", text: "sorry" } ], usage: {} }) }

    it_behaves_like "an http adapter", provider: "anthropic", model: "claude-haiku-5-5", input_tokens: 1500, output_tokens: 300

    it "uses the headers, the base64 source and a schema without minimum and maximum" do
      described_class.new(api_key: api_key, model: "claude-haiku-5-5", transport: transport).tap { |a| transport.queue(ok_reply) }
                     .analyze(image: image, content_type: "image/jpeg", prompt: prompt, schema: schema)
      call = transport.calls.first
      body = call[:body]

      expect(call[:url]).to eq("https://api.anthropic.com/v1/messages")
      expect(call[:headers]).to include("x-api-key" => api_key, "anthropic-version" => described_class::API_VERSION)
      expect(body[:messages].first[:content].first[:source]).to include(type: "base64", media_type: "image/jpeg")
      expect(body[:output_config][:format][:type]).to eq("json_schema")
      sent = JSON.generate(body[:output_config])
      expect(sent).not_to match(/"(minimum|maximum|minLength|maxLength|maxItems)"/)
      expect(sent).to include("additionalProperties")
    end
  end

  describe FoodAi::Adapters::GeminiAdapter do
    let(:ok_reply) do
      reply(200, { candidates: [ { content: { parts: [ { text: JSON.generate(payload) } ] }, finishReason: "STOP" } ],
                   usageMetadata: { promptTokenCount: 1200, candidatesTokenCount: 250, thoughtsTokenCount: 50 } })
    end
    let(:refusal_reply) { reply(200, { promptFeedback: { blockReason: "SAFETY" } }) }
    let(:non_json_reply) { reply(200, { candidates: [ { content: { parts: [ { text: "nope" } ] }, finishReason: "STOP" } ] }) }

    it_behaves_like "an http adapter", provider: "gemini", model: "gemini-3.5-flash-lite", input_tokens: 1200, output_tokens: 300

    it "keeps the key in the x-goog-api-key header and asks for JSON with the full schema" do
      described_class.new(api_key: api_key, model: "gemini-3.5-flash-lite", transport: transport).tap { |_| transport.queue(ok_reply) }
                     .analyze(image: image, content_type: "image/jpeg", prompt: prompt, schema: schema)
      call = transport.calls.first

      expect(call[:url]).to eq("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent")
      expect(call[:url]).not_to include("key=")
      expect(call[:headers]).to include("x-goog-api-key" => api_key)
      expect(call[:body][:generationConfig]).to include(responseMimeType: "application/json", responseJsonSchema: schema)
      expect(call[:body][:contents].first[:parts].first[:inlineData]).to include(mimeType: "image/jpeg")
    end

    it "a candidate stopped for safety without text is a refusal" do
      adapter = described_class.new(api_key: api_key, model: "gemini-3.5-flash-lite", transport: transport)
      transport.queue(reply(200, { candidates: [ { finishReason: "SAFETY" } ] }))

      expect { adapter.analyze(image: image, content_type: "image/jpeg", prompt: prompt, schema: schema) }
        .to raise_error(FoodAi::InvalidOutputError) { |e| expect(e.code).to eq("refusal") }
    end
  end

  describe FoodAi::Adapters::OpenaiAdapter do
    let(:ok_reply) do
      reply(200, { status: "completed",
                   output: [ { type: "message", content: [ { type: "output_text", text: JSON.generate(payload) } ] } ],
                   usage: { input_tokens: 2000, output_tokens: 400 } })
    end
    let(:refusal_reply) do
      reply(200, { output: [ { type: "message", content: [ { type: "refusal", refusal: "I cannot help" } ] } ], usage: {} })
    end
    let(:non_json_reply) { reply(200, { output: [ { type: "message", content: [ { type: "output_text", text: "hi" } ] } ], usage: {} }) }

    it_behaves_like "an http adapter", provider: "openai", model: "gpt-6-luna", input_tokens: 2000, output_tokens: 400

    it "store is false, the image is a data URL and the schema is strict" do
      described_class.new(api_key: api_key, model: "gpt-6-luna", transport: transport).tap { |_| transport.queue(ok_reply) }
                     .analyze(image: image, content_type: "image/jpeg", prompt: prompt, schema: schema)
      call = transport.calls.first
      body = call[:body]
      format = body[:text][:format]

      expect(body[:store]).to be(false)
      expect(call[:headers]).to include("authorization" => "Bearer #{api_key}")
      expect(body[:input].first[:content].last[:image_url]).to start_with("data:image/jpeg;base64,")
      expect(format).to include(type: "json_schema", strict: true)
      expect(JSON.generate(format[:schema])).not_to match(/"(minimum|maximum|minLength|maxLength|minItems|maxItems)"/)
    end

    it "every object in the strict schema requires all its properties and forbids extras" do
      adapter = described_class.new(api_key: api_key, model: "gpt-6-luna", transport: transport)
      transport.queue(ok_reply)
      adapter.analyze(image: image, content_type: "image/jpeg", prompt: prompt, schema: schema)
      sent = transport.calls.first[:body][:text][:format][:schema]
      objects = []
      collect = lambda do |node|
        case node
        when Hash then (objects << node if node["properties"]) && node.each_value(&collect)
        when Array then node.each(&collect)
        end
      end
      collect.call(sent)

      expect(objects).not_to be_empty
      objects.each do |object|
        expect(object["required"]).to match_array(object["properties"].keys)
        expect(object["additionalProperties"]).to be(false)
      end
    end
  end

  describe "SchemaTransform" do
    it "does not mutate the full schema and keeps property names that look like keywords" do
      original = { "type" => "object", "properties" => { "minimum" => { "type" => "number", "minimum" => 0 } } }
      copy = Marshal.load(Marshal.dump(original))

      result = FoodAi::Adapters::SchemaTransform.for_anthropic(original)

      expect(original).to eq(copy)
      expect(result["properties"]["minimum"]).to eq({ "type" => "number" })
    end
  end

  describe "FoodAi.adapter_for" do
    it "builds the adapter for each provider from the environment key" do
      expect(FoodAi.adapter_for(provider: "anthropic", model: "claude-haiku-5-5", env: { "ANTHROPIC_API_KEY" => "k" }))
        .to be_a(FoodAi::Adapters::AnthropicAdapter)
      expect(FoodAi.adapter_for(provider: "gemini", model: "gemini-3.5-flash-lite", env: { "GEMINI_API_KEY" => "k" }))
        .to be_a(FoodAi::Adapters::GeminiAdapter)
      expect(FoodAi.adapter_for(provider: "openai", model: "gpt-6-luna", env: { "OPENAI_API_KEY" => "k" }))
        .to be_a(FoodAi::Adapters::OpenaiAdapter)
    end

    it "a missing key raises a coded error that never carries a key" do
      expect { FoodAi.adapter_for(provider: "openai", model: "gpt-6-luna", env: {}) }
        .to raise_error(FoodAi::PermanentProviderError) { |e| expect(e.code).to eq("unauthorized") }
    end

    it "an unknown provider or model raises unsupported_model" do
      expect { FoodAi.adapter_for(provider: "nope", model: "x", env: {}) }.to raise_error(FoodAi::PermanentProviderError, "unsupported_model")
      expect { FoodAi.adapter_for(provider: "openai", model: "x", env: { "OPENAI_API_KEY" => "k" }) }
        .to raise_error(FoodAi::PermanentProviderError, "unsupported_model")
    end
  end
end

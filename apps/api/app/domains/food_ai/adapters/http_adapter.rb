require "json"
require "net/http"
require "openssl"
require "zlib"

module FoodAi
  module Adapters
    # Shared flow of the three HTTP adapters: build the provider request, post it through the
    # transport, classify HTTP errors, extract the JSON text and the token counts. Subclasses
    # define request(...) and extract(parsed). The API key travels only in a header, and no
    # error carries anything but a code (never the key, the image, the prompt or the output).
    class HttpAdapter < ProviderAdapter
      PROVIDER = nil
      MAX_OUTPUT_TOKENS = 4096

      def initialize(api_key:, model:, transport: HttpTransport.new)
        super()
        @api_key = api_key.to_s
        @model = model.to_s
        @transport = transport
      end

      def analyze(image:, content_type:, prompt:, schema:)
        url, headers, body = request(image: image, content_type: content_type, prompt: prompt, schema: schema)
        response = post(url, headers, body)
        classify_status!(response.status)
        text, input_tokens, output_tokens = extract(parse_envelope(response.body))
        build_response(parse_payload(text), input_tokens, output_tokens)
      end

      private

      attr_reader :api_key, :model

      def post(url, headers, body)
        @transport.post_json(url: url, headers: headers, body: body, timeout: HttpTransport::DEFAULT_TIMEOUT)
      rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, Timeout::Error
        raise TransientProviderError, "timeout"
      rescue SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError, Net::ProtocolError, Net::HTTPBadResponse,
             Net::HTTPHeaderSyntaxError, Zlib::Error
        raise TransientProviderError, "provider_unavailable"
      end

      def classify_status!(status)
        return if (200..299).cover?(status)

        raise TransientProviderError, "timeout" if status == 408
        raise TransientProviderError, "rate_limited" if status == 429
        raise TransientProviderError, "provider_unavailable" if status >= 500
        raise PermanentProviderError, "unauthorized" if [ 401, 403 ].include?(status)
        raise PermanentProviderError, "model_unavailable" if status == 404

        raise PermanentProviderError, "bad_request"
      end

      def parse_envelope(body)
        parsed = JSON.parse(body)
        parsed.is_a?(Hash) ? parsed : raise(InvalidOutputError, "not_an_object")
      rescue JSON::ParserError
        raise InvalidOutputError, "not_an_object"
      end

      def parse_payload(text)
        payload = JSON.parse(text.to_s)
        payload.is_a?(Hash) ? payload : raise(InvalidOutputError, "not_an_object")
      rescue JSON::ParserError
        raise InvalidOutputError, "not_an_object"
      end

      def build_response(payload, input_tokens, output_tokens)
        cost = Pricing.cost_usd(provider: self.class::PROVIDER, model: model, input_tokens: input_tokens, output_tokens: output_tokens)
        ProviderResponse.new(payload: payload, provider: self.class::PROVIDER, model: model, input_tokens: input_tokens,
                             output_tokens: output_tokens, cost_usd: cost)
      rescue Pricing::UnknownModelError
        raise PermanentProviderError, "unsupported_model"
      end

      # A token count the provider reported: an Integer of zero or more, else the answer is
      # unusable (a silent 0 would corrupt cost records and the quota).
      def tokens!(value)
        value.is_a?(Integer) && !value.negative? ? value : raise(InvalidOutputError, "missing_usage")
      end

      def hash_or_empty(value) = value.is_a?(Hash) ? value : {}

      def base64(image) = [ image ].pack("m0")
    end
  end
end

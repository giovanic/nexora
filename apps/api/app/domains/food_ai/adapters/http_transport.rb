require "json"
require "net/http"
require "uri"

module FoodAi
  module Adapters
    # The only place that touches the network for the AI providers: one JSON POST over Net::HTTP.
    # It never logs the URL, the headers or the body. Timeouts and connection errors propagate
    # as the Net/Timeout/system exceptions; the adapters turn them into coded errors.
    class HttpTransport
      Response = Data.define(:status, :body)

      DEFAULT_TIMEOUT = 45

      def post_json(url:, headers:, body:, timeout: DEFAULT_TIMEOUT)
        uri = URI.parse(url)
        raise ArgumentError, "https only" unless uri.is_a?(URI::HTTPS)

        request = Net::HTTP::Post.new(uri, { "content-type" => "application/json" }.merge(headers))
        request.body = JSON.generate(body)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = timeout
        http.read_timeout = timeout
        http.write_timeout = timeout
        raw = http.request(request)
        Response.new(status: raw.code.to_i, body: raw.body.to_s)
      end
    end
  end
end

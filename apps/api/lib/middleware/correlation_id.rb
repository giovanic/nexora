require "observability/correlation"

module Middleware
  class CorrelationId
    # Anything else is replaced, so a client cannot inject content into the logs.
    VALID = /\A[A-Za-z0-9_-]{8,64}\z/

    def initialize(app)
      @app = app
    end

    def call(env)
      id = resolve(env["HTTP_X_CORRELATION_ID"])

      Observability::Correlation.with(id) do
        status, headers, body = @app.call(env)
        headers["x-correlation-id"] = id
        [ status, headers, body ]
      end
    end

    private

    def resolve(incoming)
      incoming&.b&.match?(VALID) ? incoming : Observability::Correlation.generate
    end
  end
end

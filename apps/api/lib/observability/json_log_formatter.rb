require "json"
require "observability/correlation"

module Observability
  class JsonLogFormatter
    def call(severity, time, _progname, message)
      "#{JSON.generate(line(severity, time, message))}\n"
    end

    private

    def line(severity, time, message)
      base = { timestamp: time.utc.iso8601(3), level: severity }
      context = sidekiq_context
      correlation_id = Observability::Correlation.id || context[:correlation_id]

      base[:correlation_id] = correlation_id if correlation_id
      base[:context] = context.except(:correlation_id) if context.any?

      message.is_a?(Hash) ? base.merge(message) : base.merge(message: text(message))
    end

    def text(message)
      message.is_a?(Exception) ? message.class.name : message.to_s.scrub
    end

    def sidekiq_context
      defined?(Sidekiq::Context) ? Sidekiq::Context.current : {}
    end
  end
end

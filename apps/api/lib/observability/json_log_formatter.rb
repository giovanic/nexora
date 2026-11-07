require "json"
require "observability/correlation"

module Observability
  class JsonLogFormatter
    # Sidekiq's context can also hold the job hash, with its arguments.
    KEPT_JOB_FIELDS = %i[jid class elapsed queue].freeze

    def call(severity, time, _progname, message)
      "#{JSON.generate(clean(line(severity, time, message)))}\n"
    end

    private

    def line(severity, time, message)
      base = { timestamp: time.utc.iso8601(3), level: severity }
      context = sidekiq_context
      correlation_id = Observability::Correlation.id || context[:correlation_id]
      job = context.slice(*KEPT_JOB_FIELDS)

      base[:correlation_id] = correlation_id if correlation_id
      base[:context] = job if job.any?

      message.is_a?(Hash) ? message.merge(base) : base.merge(message: text(message))
    end

    def text(message)
      message.is_a?(Exception) ? message.class.name : message.to_s
    end

    def clean(value)
      case value
      when Hash then value.transform_values { |item| clean(item) }
      when Array then value.map { |item| clean(item) }
      when String then value.scrub
      else value
      end
    end

    def sidekiq_context
      defined?(Sidekiq::Context) ? Sidekiq::Context.current : {}
    end
  end
end

require "sidekiq"
require "observability/correlation"

module Observability
  module SidekiqCorrelation
    # Stamps the job with the current request's identifier, or a new one when
    # the job starts outside a request.
    class Client
      include Sidekiq::ClientMiddleware

      def call(_job_class, job, _queue, _redis_pool)
        job["correlation_id"] ||= Observability::Correlation.id || Observability::Correlation.generate
        yield
      end
    end

    class Server
      include Sidekiq::ServerMiddleware

      def call(_job_instance, job, _queue, &block)
        Observability::Correlation.with(job["correlation_id"], &block)
      end
    end

    # Replaces Sidekiq's default handler, which logs the exception message and,
    # through its context, the job arguments. Either can carry user data.
    ERROR_LOG = lambda do |exception, context, config = Sidekiq.default_configuration|
      config.logger.warn do
        { message: "job failed", error: exception.class.name, jid: context.dig(:job, "jid") }.compact
      end
    end
  end
end

require "observability/json_log_formatter"
require "observability/sidekiq_correlation"

Sidekiq.configure_client do |config|
  config.redis = { url: Rails.configuration.x.queue_url }

  config.client_middleware { |chain| chain.add Observability::SidekiqCorrelation::Client }
end

Sidekiq.configure_server do |config|
  config.redis = { url: Rails.configuration.x.queue_url }
  config.logger.formatter = Observability::JsonLogFormatter.new

  # Sidekiq copies these job attributes into the context of every log line,
  # including the "start" and "done" lines written outside the middleware chain.
  config[:logged_job_attributes] += [ "correlation_id" ]

  config.error_handlers.delete(Sidekiq::Config::ERROR_HANDLER)
  config.error_handlers << Observability::SidekiqCorrelation::ERROR_LOG

  config.client_middleware { |chain| chain.add Observability::SidekiqCorrelation::Client }
  config.server_middleware { |chain| chain.add Observability::SidekiqCorrelation::Server }
end

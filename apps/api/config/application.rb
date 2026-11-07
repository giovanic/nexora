require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
# require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
require "action_controller/railtie"
# require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Backend
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1


    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    require "api_error_app"
    require "middleware/correlation_id"
    require "observability/json_log_formatter"

    config.exceptions_app = ApiErrorApp.new
    config.middleware.insert_before Rails::Rack::Logger, Middleware::CorrelationId

    config.log_level = ENV.fetch("LOG_LEVEL", "info")
    config.log_formatter = Observability::JsonLogFormatter.new
    config.log_tags = []
    # Rails logs the full exception at this level. Keep it below the default, as
    # its message can carry user data; the error tracker receives class and stack.
    config.action_dispatch.debug_exception_log_level = :debug

    # Local defaults match docker-compose.yml. Production requires REDIS_URL,
    # the name Sidekiq reads, even though the service is Valkey.
    local_queue_urls = { "development" => "redis://127.0.0.1:6380/0", "test" => "redis://127.0.0.1:6380/1" }
    config.x.queue_url = ENV.fetch("REDIS_URL") { local_queue_urls[Rails.env] }
  end
end

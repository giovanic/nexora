require "allowed_origins"

# Also read by the Authentication concern, which asks cookie requests that
# change state for one of these origins.
Rails.application.config.x.allowed_origins = AllowedOrigins.from(ENV.to_h, environment: Rails.env.to_s).freeze

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*Rails.application.config.x.allowed_origins)

    resource "/health/*", headers: :any, methods: %i[get head options]
  end
end

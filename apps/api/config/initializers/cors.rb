require "allowed_origins"

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*AllowedOrigins.from(ENV.to_h, environment: Rails.env.to_s))

    resource "/health/*", headers: :any, methods: %i[get head options]
  end
end

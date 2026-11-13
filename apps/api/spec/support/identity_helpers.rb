# Helpers for request specs of accounts and sessions. Requests go over HTTPS,
# since the browser only keeps the __Host- cookie on a secure origin.
module IdentityHelpers
  WEB_ORIGIN = "http://localhost:5173".freeze
  PASSWORD = "correct horse battery".freeze

  def self.included(base)
    base.include ActiveSupport::Testing::TimeHelpers
    base.before { https! }
  end

  def registration_body(**overrides)
    { email: "ana@example.test", password: PASSWORD, adult_confirmed: true, time_zone: "America/Sao_Paulo",
      client: "mobile", device_label: "Pixel 8" }.merge(overrides)
  end

  def sign_up(headers: {}, env: {}, **overrides)
    headers = headers.merge("Origin" => WEB_ORIGIN) if overrides[:client] == "web" && !headers.key?("Origin")
    post "/api/v1/registrations", params: registration_body(**overrides), headers:, env:, as: :json
  end

  def sign_in(email: "ana@example.test", password: PASSWORD, client: "mobile", headers: {}, env: {}, **extra)
    headers = headers.merge("Origin" => WEB_ORIGIN) if client == "web" && !headers.key?("Origin")
    post "/api/v1/sessions", params: { email:, password:, client:, **extra }, headers:, env:, as: :json
  end

  # Signs up on mobile and returns the token.
  def mobile_token(email: "ana@example.test")
    sign_up(email:)
    response.parsed_body.fetch("token")
  end

  def bearer(token)
    { "Authorization" => "Bearer #{token}" }
  end

  def session_cookie_header
    Array(response.headers["Set-Cookie"]).join("\n").lines.find { |line| line.start_with?("__Host-session=") }
  end
end

RSpec.configure { |config| config.include IdentityHelpers, :identity }

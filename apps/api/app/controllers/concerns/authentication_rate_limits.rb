# Limits for sign up, sign in, refresh and password reset (design 4.1 and ruling R7). Keys are
# keyed hashes, so the cache never holds an IP or an e-mail in clear.
module AuthenticationRateLimits
  extend ActiveSupport::Concern

  BY_IP = { to: 10, within: 3.minutes }.freeze
  BY_EMAIL = { to: 5, within: 15.minutes }.freeze

  class_methods do
    def limit_attempts_by_ip(action)
      rate_limit(**BY_IP, name: "#{action}_ip", only: action,
                 by: -> { rate_limit_key(request.remote_ip) }, with: -> { refuse_attempt(BY_IP[:within]) })
    end

    def limit_attempts_by_email(action)
      rate_limit(**BY_EMAIL, name: "#{action}_email", only: action,
                 by: -> { rate_limit_key(Identity::Api.normalize_email(params[:email])) }, with: -> { refuse_attempt(BY_EMAIL[:within]) })
    end
  end

  private

  def rate_limit_key(value)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("authentication rate limit"), value.to_s)
  end

  def refuse_attempt(window)
    response.headers["Retry-After"] = window.to_i.to_s
    render_error(:too_many_requests)
  end
end

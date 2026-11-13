# Limits for sign up, sign in, refresh and password reset (design 4.1 and ruling R7). Keys are
# keyed hashes, so the cache never holds an IP or an e-mail in clear.
module AuthenticationRateLimits
  extend ActiveSupport::Concern

  BY_IP = { to: 10, within: 3.minutes }.freeze
  # Sign up: every request counts (nothing to lock out, the account does not exist yet).
  BY_EMAIL = { to: 5, within: 15.minutes }.freeze
  # Sign in counts failed attempts only: a correct password gives its slot back.
  # Trade-off: five wrong passwords for an e-mail still refuse that person's
  # sign in for 15 minutes, from any IP. The per-IP limit and the password hash
  # cost are the other brakes; the slot is taken before the password check, so
  # parallel requests cannot all get a check.
  FAILED_SIGN_INS_BY_EMAIL = { to: 5, within: 15.minutes }.freeze
  # Password reset always answers 202, so a failure cannot be seen and every
  # request counts. The value is generous (20 in an hour) so a person is never
  # blocked by normal use; it only caps e-mail flooding of one address.
  RESETS_BY_EMAIL = { to: 20, within: 1.hour }.freeze
  BY_ACCOUNT = { to: 5, within: 15.minutes }.freeze

  class_methods do
    def limit_attempts_by_ip(action)
      rate_limit(**BY_IP, name: "#{action}_ip", only: action,
                 by: -> { rate_limit_key(request.remote_ip) }, with: -> { refuse_attempt(BY_IP[:within]) })
    end

    # Re-authentication (export, deletion): a stolen session token must not
    # allow unlimited password guesses by rotating IPs. Needs the session.
    def limit_attempts_by_account(action)
      rate_limit(**BY_ACCOUNT, name: "#{action}_account", only: action,
                 by: -> { rate_limit_key("account:#{current_user_id}") }, with: -> { refuse_attempt(BY_ACCOUNT[:within]) })
    end

    def limit_attempts_by_email(action)
      rate_limit(**BY_EMAIL, name: "#{action}_email", only: action,
                 by: -> { rate_limit_key(Identity::Api.normalize_email(params[:email])) }, with: -> { refuse_attempt(BY_EMAIL[:within]) })
    end

    def limit_resets_by_email(action)
      rate_limit(**RESETS_BY_EMAIL, name: "#{action}_email", only: action,
                 by: -> { rate_limit_key(Identity::Api.normalize_email(params[:email])) }, with: -> { refuse_attempt(RESETS_BY_EMAIL[:within]) })
    end

    # Takes one slot of the e-mail before the password is checked (atomic
    # increment) and answers 429 when the slot is beyond the limit. The action
    # calls release_sign_in_slot when the password is right.
    def refuse_after_failed_sign_ins(action)
      before_action(only: action) do
        taken = Rails.cache.increment(failed_sign_in_key, 1, expires_in: FAILED_SIGN_INS_BY_EMAIL[:within])
        refuse_attempt(FAILED_SIGN_INS_BY_EMAIL[:within]) if taken.to_i > FAILED_SIGN_INS_BY_EMAIL[:to]
      end
    end
  end

  private

  def rate_limit_key(value)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("authentication rate limit"), value.to_s)
  end

  def failed_sign_in_key
    rate_limit_key("failed sign in:#{Identity::Api.normalize_email(params[:email])}")
  end

  def release_sign_in_slot
    Rails.cache.decrement(failed_sign_in_key, 1, expires_in: FAILED_SIGN_INS_BY_EMAIL[:within])
  end

  def refuse_attempt(window)
    response.headers["Retry-After"] = window.to_i.to_s
    render_error(:too_many_requests)
  end
end

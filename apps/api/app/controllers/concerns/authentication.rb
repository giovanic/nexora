# Reads the session from Authorization: Bearer (mobile) or from the signed
# __Host-session cookie (web), and exposes current_user_id. A request that uses
# or asks for the cookie and changes state needs an Origin from AllowedOrigins,
# since the API does not use Rails' form CSRF protection (design 4.1).
module Authentication
  extend ActiveSupport::Concern

  SESSION_COOKIE = "__Host-session".freeze

  included do
    include ActionController::Cookies

    before_action :send_no_store
    before_action :refuse_foreign_origin
    before_action :require_authentication
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end

    # Runs after the session check, and answers 403 consent_required unless
    # the latest record of the purpose is a grant (design 4.5).
    def require_consent(purpose, **options)
      raise ArgumentError, "unknown consent purpose" unless Identity::Api.consent_purpose?(purpose.to_s)

      before_action(**options) do
        render_error(:forbidden, "consent_required") unless Identity::Api.consent_granted?(user_id: current_user_id, purpose: purpose.to_s)
      end
    end
  end

  private

  def current_user_id
    current_session&.user_id
  end

  def current_session
    return @current_session if defined?(@current_session)

    @current_session = Identity::Api.session_for(token: session_token)
  end

  def session_token
    bearer_token || cookie_token
  end

  def bearer_token
    request.authorization.to_s[/\ABearer ([^\s]+)\z/, 1]
  end

  def cookie_token
    cookies.signed[SESSION_COOKIE]
  end

  def cookie_transport?
    bearer_token.nil? && (cookie_token.present? || params[:client] == "web")
  end

  # Every answer of the API is about one person: no cache, shared or private,
  # keeps it (set once here, before any filter can answer).
  def send_no_store
    response.headers["Cache-Control"] = "no-store"
  end

  def require_authentication
    render_error(:unauthorized) unless current_session
  end

  def refuse_foreign_origin
    return if request.get? || request.head? || !cookie_transport?

    render_error(:forbidden) unless Rails.configuration.x.allowed_origins.include?(request.origin)
  end

  # Web gets the cookie and no token in the body; mobile gets the token.
  def render_session(result, client:, status:)
    body = { user_id: result.user_id, expires_at: result.expires_at.iso8601 }
    if client == "web"
      cookies.signed[SESSION_COOKIE] = { value: result.session_token, expires: result.expires_at, httponly: true, secure: true, same_site: :lax, path: "/" }
    else
      body[:token] = result.session_token
    end

    render json: body, status:
  end

  def forget_session_cookie
    cookies.delete(SESSION_COOKIE, httponly: true, secure: true, same_site: :lax, path: "/")
  end
end

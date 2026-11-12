module Identity
  # The only entry point to Identity for other contexts and controllers. It
  # returns Data objects, never models.
  module Api
    CLIENTS = Session::CLIENTS
    MAX_SESSIONS_LISTED = 100
    USER_DATA_TABLES = %w[users sessions audit_events].freeze

    Result = Data.define(:session_token, :user_id, :expires_at) do
      def ok? = true
    end
    # details: [{ field:, code: }], never the submitted values.
    Errors = Data.define(:code, :details) do
      def ok? = false
    end
    SessionInfo = Data.define(:id, :user_id, :client, :device_label, :created_at, :last_used_at)

    class << self
      # Code outside Identity reaches only this module, so it asks instead of reading CLIENTS.
      def client?(value)
        CLIENTS.include?(value)
      end

      def register(email:, password:, adult_confirmed:, time_zone:, client:, device_label:, ip:)
        Register.call(email:, password:, adult_confirmed:, time_zone:, client:, device_label:, ip:)
      end

      def authenticate(email:, password:, client:, device_label:, ip:)
        Authenticate.call(email:, password:, client:, device_label:, ip:)
      end

      # Every use pushes the idle deadline, never past the absolute one.
      def session_for(token:)
        return if token.blank?

        session = Session.usable.find_by(token_digest: Session.digest(token))
        return unless session

        session.record_use!
        info(session)
      end

      def refresh(token:)
        RefreshSession.call(token:)
      end

      def sessions(user_id:)
        Session.usable.where(user_id:).order(last_used_at: :desc).limit(MAX_SESSIONS_LISTED).map { |session| info(session) }
      end

      def revoke_session(user_id:, session_id:)
        RevokeSession.call(user_id:, session_id:)
      end

      def revoke_all(user_id:)
        RevokeSession.all(user_id:)
      end

      def verify_password(user_id:, password:)
        return false unless password.is_a?(String)

        User.active.find_by(id: user_id)&.authenticate(password).present?
      end

      # The account's own normalization, for callers that key on the e-mail,
      # such as the rate limit per e-mail.
      def normalize_email(email)
        User.normalize_value_for(:email, email.to_s)
      end

      # Always nil, whether the e-mail has an account or not.
      def request_password_reset(email:)
        RequestPasswordReset.call(email:)
      end

      # true, :invalid for a used, expired or unknown token, or Errors when the
      # new password breaks the rules.
      def reset_password(token:, password:, ip: nil)
        ResetPassword.call(token:, password:, ip:)
      end

      def export_user_data(user_id)
        UserData.export(user_id)
      end

      def erase_user_data(user_id)
        UserData.erase(user_id)
      end

      private

      def info(session)
        SessionInfo.new(id: session.id, user_id: session.user_id, client: session.client, device_label: session.device_label,
                        created_at: session.created_at, last_used_at: session.last_used_at)
      end
    end
  end
end

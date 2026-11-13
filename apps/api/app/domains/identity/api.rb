module Identity
  # The only entry point to Identity for other contexts and controllers. It
  # returns Data objects, never models.
  module Api
    CLIENTS = Session::CLIENTS
    MAX_SESSIONS_LISTED = 100
    USER_DATA_TABLES = %w[users sessions audit_events consent_records account_deletions].freeze
    Result = Data.define(:session_token, :user_id, :expires_at) do
      def ok? = true
    end
    # details: [{ field:, code: }], never the submitted values.
    Errors = Data.define(:code, :details) do
      def ok? = false
    end
    SessionInfo = Data.define(:id, :user_id, :client, :device_label, :created_at, :last_used_at)
    # state: granted, outdated (granted for a version that is not the one in
    # force), revoked or pending (never answered). accepted_version is set
    # while granted or outdated.
    Consent = Data.define(:purpose, :state, :current_version, :accepted_version, :decided_at) do
      def ok? = true
    end
    ConsentText = Data.define(:purpose, :version, :body)

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

      def consent_purpose?(purpose)
        ConsentTexts.purpose?(purpose)
      end

      # From the latest record of the purpose. Any context may ask (DOMAIN_MODEL.md).
      def consent_granted?(user_id:, purpose:)
        raise ArgumentError, "unknown consent purpose" unless ConsentTexts.purpose?(purpose)

        consent_info(purpose, ConsentRecord.latest(user_id:, purpose:)).state == "granted"
      end

      # True when the latest record of the purpose is a grant made after the
      # instant, so a consumer of an older revoke can tell it was overtaken.
      def consent_granted_after?(user_id:, purpose:, instant:)
        raise ArgumentError, "unknown consent purpose" unless ConsentTexts.purpose?(purpose)

        latest = ConsentRecord.latest(user_id:, purpose:)
        !!(latest&.granted? && latest.occurred_at > instant)
      end

      # Every purpose, in the order of ConsentTexts::PURPOSES, from one query.
      def consents(user_id:)
        latest = ConsentRecord.where(user_id:).select("DISTINCT ON (purpose) *").order(:purpose, occurred_at: :desc).index_by(&:purpose)
        ConsentTexts::PURPOSES.map { |purpose| consent_info(purpose, latest[purpose]) }
      end

      def consent(user_id:, purpose:)
        consent_info(purpose, ConsentRecord.latest(user_id:, purpose:))
      end

      # Consent, Errors (validation_failed, outdated_version) or :not_found
      # for an account that does not exist or was deleted.
      def grant_consent(user_id:, purpose:, version:, source: nil)
        GrantConsent.call(user_id:, purpose:, version:, source:)
      end

      # true, Errors (validation_failed) or :not_found.
      def revoke_consent(user_id:, purpose:, source: nil)
        RevokeConsent.call(user_id:, purpose:, source:)
      end

      # The text of the version in force, or nil for an unknown purpose.
      def consent_text(purpose:)
        return unless ConsentTexts.purpose?(purpose)

        ConsentText.new(purpose:, version: ConsentTexts.current_version(purpose), body: ConsentTexts.read(purpose))
      end

      # The person's data from every registered context, built on the spot and
      # never stored, or :invalid_password. Records that the export happened.
      def export(user_id:, password:, ip: nil)
        ExportAccount.call(user_id:, password:, ip:)
      end

      # :scheduled or :invalid_password. Ends every session at once; the data
      # goes away in the background, within 24 hours (design 4.4).
      def request_deletion(user_id:, password:, ip: nil)
        RequestDeletion.call(user_id:, password:, ip:)
      end

      # True from the request on, before the erasure ends. The outbox discards
      # the person's events from then on.
      def deletion_requested?(user_id:)
        AccountDeletion.exists?(user_id:)
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

      def consent_info(purpose, latest)
        current = ConsentTexts.current_version(purpose)
        state = if latest.nil? then "pending"
        elsif !latest.granted? then "revoked"
        elsif latest.text_version == current then "granted"
        else "outdated"
        end
        Consent.new(purpose:, state:, current_version: current,
                    accepted_version: latest&.granted? ? latest.text_version : nil, decided_at: latest&.occurred_at)
      end
    end
  end
end

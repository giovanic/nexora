module Identity
  # Signs in with e-mail and password. Wrong password, unknown e-mail and a
  # deleted account all answer :invalid, and authenticate_by spends the same
  # bcrypt time when no account matches. The failure audit holds only the
  # action and the IP hash, never the typed e-mail (design 4.7).
  module Authenticate
    def self.call(email:, password:, client:, device_label:, ip:)
      user = User.authenticate_by(email:, password:, deleted_at: nil) if email.is_a?(String) && password.is_a?(String)
      return failed(ip) unless user

      User.transaction do
        session, token = Session.start!(user_id: user.id, client:, device_label: (device_label if device_label.is_a?(String)))
        RecordAudit.call(action: "sign_in", user_ref: user.id, metadata: { client: }, ip:)
        Api::Result.new(session_token: token, user_id: user.id, expires_at: session.absolute_expires_at)
      end
    end

    def self.failed(ip)
      RecordAudit.call(action: "sign_in_failed", ip:)
      :invalid
    end
    private_class_method :failed
  end
end

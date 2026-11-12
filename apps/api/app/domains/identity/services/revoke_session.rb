module Identity
  # Signs a device out, or every device of a user. Another person's session
  # answers :not_found, as if it did not exist.
  module RevokeSession
    def self.call(user_id:, session_id:)
      session = Session.where(revoked_at: nil).find_by(user_id:, id: session_id)
      return :not_found unless session

      Session.transaction do
        session.revoke!
        RecordAudit.call(action: "session_revoked", user_ref: user_id, ip: nil)
      end
      true
    end

    def self.all(user_id:)
      now = Time.current
      Session.transaction do
        Session.where(user_id:, revoked_at: nil).update_all(revoked_at: now, updated_at: now)
        RecordAudit.call(action: "all_sessions_revoked", user_ref: user_id, ip: nil)
      end
      true
    end
  end
end

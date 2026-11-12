module Identity
  # Swaps a session token for a new one. The row is locked, so of two refreshes
  # with the same token only the first finds it usable; the second waits for
  # its commit, sees it revoked and gets nil (design 4.1).
  module RefreshSession
    def self.call(token:)
      return if token.blank?

      Session.transaction do
        session = Session.usable.lock("FOR UPDATE OF sessions").find_by(token_digest: Session.digest(token))
        next unless session

        session.revoke!
        renewed, new_token = Session.start!(user_id: session.user_id, client: session.client, device_label: session.device_label,
                                            absolute_expires_at: session.absolute_expires_at)
        Api::Result.new(session_token: new_token, user_id: renewed.user_id, expires_at: renewed.absolute_expires_at)
      end
    end
  end
end

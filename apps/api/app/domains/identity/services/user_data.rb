module Identity
  # Identity's part of account export and deletion, through Shared::DataRegistry.
  # Export leaves out secrets: password and token digests, and the IP hash.
  module UserData
    def self.export(user_id)
      user = User.find_by(id: user_id)
      {
        user: user && { id: user.id, email: user.email, adult_confirmed_at: user.adult_confirmed_at, created_at: user.created_at },
        sessions: Session.where(user_id:).order(:created_at).map do |session|
          session.slice(:id, :client, :device_label, :created_at, :last_used_at, :revoked_at).symbolize_keys
        end,
        audit_events: AuditEvent.where(user_ref: user_id).order(:occurred_at).map do |audit|
          audit.slice(:action, :metadata, :occurred_at).symbolize_keys
        end,
        consent_records: ConsentRecord.where(user_id:).order(:occurred_at).map do |record|
          record.slice(:purpose, :text_version, :action, :source, :occurred_at).symbolize_keys
        end
      }
    end

    # Only the sessions go here. The users row is anonymized by the deletion
    # flow after every context is erased, and audit_events and consent_records
    # stay linked to the same UUID, with no health content (design 4.4).
    # account_deletions stays as the record for backup restores, and is not
    # exported: an account with one can no longer sign in. Safe to run again.
    def self.erase(user_id)
      Session.where(user_id:).delete_all
    end
  end
end

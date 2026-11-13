module Identity
  # Records the revoke of a granted purpose, with the version that was
  # accepted. Every purpose, health_data included, is revoked the same way
  # (owner decision of 2026-11-13); each context reacts to consent.revoked.
  # Revoking a purpose that is not granted writes nothing.
  module RevokeConsent
    def self.call(user_id:, purpose:, source: nil)
      return ConsentRecord.unknown_purpose unless ConsentTexts.purpose?(purpose)

      ConsentRecord.transaction do
        next :not_found unless User.active.lock.find_by(id: user_id)

        latest = ConsentRecord.latest(user_id:, purpose:)
        record(user_id:, purpose:, source:, latest:) if latest&.granted?
        true
      end
    end

    def self.record(user_id:, purpose:, source:, latest:)
      version = latest.text_version
      ConsentRecord.create!(user_id:, purpose:, text_version: version, action: "revoked", source:, occurred_at: ConsentRecord.next_instant(latest))
      RecordAudit.call(action: "consent_revoked", user_ref: user_id, metadata: { purpose: }, ip: nil)
      Shared::Outbox.publish!(name: "consent.revoked", user_id:, payload: { purpose:, version: })
    end
    private_class_method :record
  end
end

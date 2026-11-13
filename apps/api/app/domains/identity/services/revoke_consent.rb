module Identity
  # Records the revoke of a granted purpose, with the version that was
  # accepted. health_data is what the product does, so it is not revoked here:
  # it answers deletion_required, and the app leads to account deletion, which
  # has its own confirmation (design 4.5). Revoking a purpose that is not
  # granted writes nothing.
  module RevokeConsent
    REQUIRES_DELETION = %w[health_data].freeze

    def self.call(user_id:, purpose:, source: nil)
      return ConsentRecord.unknown_purpose unless ConsentTexts.purpose?(purpose)
      return Api::Errors.new(code: "deletion_required", details: []) if REQUIRES_DELETION.include?(purpose)

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

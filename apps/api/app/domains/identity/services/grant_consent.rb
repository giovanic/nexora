module Identity
  # Records the grant of a purpose, for the version of the text in force only.
  # The record, the audit and consent.granted are written together. Granting a
  # purpose already granted with that version writes nothing. A new health_data
  # grant waits for the earlier withdrawal to be applied (revocation_pending).
  module GrantConsent
    def self.call(user_id:, purpose:, version:, source: nil)
      return ConsentRecord.unknown_purpose unless ConsentTexts.purpose?(purpose)
      unless version.is_a?(Integer)
        return Api::Errors.new(code: "validation_failed", details: [ { field: "version", code: "not_an_integer" } ])
      end
      unless version == ConsentTexts.current_version(purpose)
        return Api::Errors.new(code: "outdated_version", details: [ { field: "version", code: "outdated" } ])
      end

      ConsentRecord.transaction do
        # The lock puts the decisions of one person in a row, so the latest record stays the latest.
        next :not_found unless User.active.lock.find_by(id: user_id)

        # health_data: what the person withdrew must be erased before a new grant,
        # or the old data would come back under it (owner ruling R34).
        next revocation_pending if purpose == "health_data" && withdrawal_pending?(user_id)

        latest = ConsentRecord.latest(user_id:, purpose:)
        record(user_id:, purpose:, version:, source:, latest:) unless latest&.granted? && latest.text_version == version
        Api.consent(user_id:, purpose:)
      end
    end

    def self.record(user_id:, purpose:, version:, source:, latest:)
      ConsentRecord.create!(user_id:, purpose:, text_version: version, action: "granted", source:, occurred_at: ConsentRecord.next_instant(latest))
      RecordAudit.call(action: "consent_granted", user_ref: user_id, metadata: { purpose: }, ip: nil)
      Shared::Outbox.publish!(name: "consent.granted", user_id:, payload: { purpose:, version: })
    end
    private_class_method :record

    def self.withdrawal_pending?(user_id)
      Shared::Outbox.undelivered?(name: "consent.revoked", user_id:, payload: { purpose: "health_data" })
    end

    def self.revocation_pending
      Api::Errors.new(code: "revocation_pending", details: [])
    end
    private_class_method :withdrawal_pending?, :revocation_pending
  end
end

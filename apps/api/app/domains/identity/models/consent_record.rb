module Identity
  # One grant or revoke of a purpose. Append-only: GrantConsent and
  # RevokeConsent are the only writers, and the latest record of a purpose is
  # its current state (DATABASE_DESIGN.md).
  class ConsentRecord < ApplicationRecord
    self.table_name = "consent_records"

    ACTIONS = %w[granted revoked].freeze

    belongs_to :user, class_name: "Identity::User"

    validates :purpose, inclusion: { in: ConsentTexts::PURPOSES }
    validates :action, inclusion: { in: ACTIONS }
    validates :source, inclusion: { in: Session::CLIENTS }, allow_nil: true

    scope :latest_first, -> { order(occurred_at: :desc) }

    def self.latest(user_id:, purpose:)
      where(user_id:, purpose:).latest_first.first
    end

    # Now, or just after the latest record when the clock has not moved past
    # it, so the order of decisions never depends on a tie. The unique index on
    # (user_id, purpose, occurred_at) is the last defense.
    def self.next_instant(latest, now: Time.current)
      return now unless latest

      [ now, latest.occurred_at + Rational(1, 1_000_000) ].max
    end

    def self.unknown_purpose
      Api::Errors.new(code: "validation_failed", details: [ { field: "purpose", code: "inclusion" } ])
    end

    def granted?
      action == "granted"
    end

    def readonly?
      persisted? || super
    end
  end
end

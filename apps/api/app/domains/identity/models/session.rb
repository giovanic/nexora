module Identity
  # One signed-in device. The token itself is never stored, only its SHA-256
  # digest (design 4.1).
  class Session < ApplicationRecord
    self.table_name = "sessions"

    CLIENTS = %w[web mobile].freeze
    IDLE_TIMEOUT = 30.days
    ABSOLUTE_TIMEOUT = 90.days
    TOKEN_BYTES = 32
    MAX_DEVICE_LABEL = 100

    belongs_to :user, class_name: "Identity::User"

    # A label the device sends ("iPhone de <Name>"), shown only to its owner,
    # so it is encrypted like the profile name. Never search by it. Cut instead
    # of refused, so an odd label never blocks a sign in; cut before encrypting,
    # since the encrypted value is longer.
    encrypts :device_label
    normalizes :device_label, with: ->(label) { label.strip.first(MAX_DEVICE_LABEL).presence }

    validates :client, inclusion: { in: CLIENTS }

    scope :active, ->(now = Time.current) {
      where(revoked_at: nil).where("sessions.idle_expires_at > :now AND sessions.absolute_expires_at > :now", now:)
    }
    # Active, and of an account that was not deleted.
    scope :usable, ->(now = Time.current) { active(now).joins(:user).merge(User.active) }

    def self.digest(token)
      OpenSSL::Digest::SHA256.hexdigest(token.to_s)
    end

    # Returns the session and the only copy of its token. A refreshed session
    # keeps the absolute deadline of the one it replaces.
    def self.start!(user_id:, client:, device_label:, absolute_expires_at: nil, now: Time.current)
      token = SecureRandom.urlsafe_base64(TOKEN_BYTES)
      absolute_expires_at ||= now + ABSOLUTE_TIMEOUT
      session = create!(
        user_id:, client:, device_label:, token_digest: digest(token), last_used_at: now,
        idle_expires_at: [ now + IDLE_TIMEOUT, absolute_expires_at ].min, absolute_expires_at:
      )
      [ session, token ]
    end

    def record_use!(now = Time.current)
      update_columns(last_used_at: now, idle_expires_at: [ now + IDLE_TIMEOUT, absolute_expires_at ].min, updated_at: now)
    end

    def revoke!(now = Time.current)
      update!(revoked_at: now)
    end
  end
end

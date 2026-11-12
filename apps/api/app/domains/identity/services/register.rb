module Identity
  # Creates the account and its first session. Nothing is written unless every
  # input is valid. An existing e-mail answers email_taken, the exception the
  # design accepts while there is no e-mail verification (design 4.10).
  module Register
    FIELDS = { adult_confirmed_at: "adult_confirmed" }.freeze
    CODES = { adult_confirmed_at: { blank: "required" } }.freeze

    def self.call(email:, password:, adult_confirmed:, time_zone:, client:, device_label:, ip:)
      return refusal("invalid_time_zone", field: "time_zone", reason: "invalid") unless time_zone?(time_zone)

      user = User.new(email: text(email), password: text(password), adult_confirmed_at: adult_confirmed == true ? Time.current : nil)
      user.valid?
      return refusal("email_taken", field: "email", reason: "taken") if user.errors.of_kind?(:email, :taken)

      details = user.errors.map { |failure| detail_for(failure) }
      details << { field: "client", code: "inclusion" } unless Session::CLIENTS.include?(client)
      return Api::Errors.new(code: "validation_failed", details: details.uniq) if details.any?

      create(user, time_zone:, client:, device_label:, ip:)
    end

    def self.create(user, time_zone:, client:, device_label:, ip:)
      User.transaction do
        user.save!
        session, token = Session.start!(user_id: user.id, client:, device_label: text(device_label))
        RecordAudit.call(action: "sign_up", user_ref: user.id, metadata: { client: }, ip:)
        Shared::Outbox.publish!(name: "user.registered", user_id: user.id, payload: { time_zone: })
        Api::Result.new(session_token: token, user_id: user.id, expires_at: session.absolute_expires_at)
      end
    rescue ActiveRecord::RecordNotUnique => conflict
      raise unless conflict.message.include?("index_users_on_email")

      refusal("email_taken", field: "email", reason: "taken")
    end

    # Any zone TZInfo knows, which the outbox payload check also accepts.
    def self.time_zone?(value)
      value.is_a?(String) && TZInfo::Timezone.all_identifiers.include?(value)
    end

    def self.text(value)
      value if value.is_a?(String)
    end

    def self.detail_for(failure)
      code = CODES.dig(failure.attribute, failure.type) || failure.type.to_s
      { field: FIELDS.fetch(failure.attribute, failure.attribute.to_s), code: }
    end

    def self.refusal(code, field:, reason:)
      Api::Errors.new(code:, details: [ { field:, code: reason } ])
    end

    private_class_method :create, :time_zone?, :text, :detail_for, :refusal
  end
end

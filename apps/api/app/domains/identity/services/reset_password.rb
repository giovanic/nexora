module Identity
  # Sets a new password from a reset token. The row is locked before the token
  # is checked, so of two resets with the same token the second sees the new
  # salt and gets :invalid. Every session ends, and none is opened (design 4.1).
  module ResetPassword
    def self.call(token:, password:, ip: nil)
      return :invalid unless token.is_a?(String)

      User.transaction do
        user = User.active.lock.find_by_password_reset_token(token)
        next :invalid unless user
        next refusal("blank") unless password.is_a?(String) && !password.empty?

        user.password = password
        next refusal(user.errors.details.dig(:password, 0, :error) || "invalid") unless user.valid?

        user.save!
        RevokeSession.all(user_id: user.id)
        RecordAudit.call(action: "password_reset", user_ref: user.id, ip:)
        true
      end
    end

    def self.refusal(reason)
      Api::Errors.new(code: "validation_failed", details: [ { field: "password", code: reason.to_s } ])
    end
    private_class_method :refusal
  end
end

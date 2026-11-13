module Identity
  # Account export (LGPD): the password is asked again, the data comes from
  # every registered context, and nothing is written to disk. The audit event
  # says only that it happened.
  module ExportAccount
    def self.call(user_id:, password:, ip:)
      unless Api.verify_password(user_id:, password:)
        RecordAudit.call(action: "reauth_failed", user_ref: user_id, ip:, metadata: { for: "export" })
        return :invalid_password
      end

      data = Shared::DataRegistry.export(user_id:)
      RecordAudit.call(action: "account_exported", user_ref: user_id, ip:)
      data
    end
  end
end

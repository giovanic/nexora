module Identity
  # Account export (LGPD): the password is asked again, the data comes from
  # every registered context, and nothing is written to disk. The audit event
  # says only that it happened.
  module ExportAccount
    def self.call(user_id:, password:, ip:)
      return :invalid_password unless Api.verify_password(user_id:, password:)

      data = Shared::DataRegistry.export(user_id:)
      RecordAudit.call(action: "account_exported", user_ref: user_id, ip:)
      data
    end
  end
end

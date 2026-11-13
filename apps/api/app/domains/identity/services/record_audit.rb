module Identity
  # Writes one audit event. Metadata follows a closed list per action, and each
  # field takes only closed-list values, so no e-mail, token or free text gets
  # in (design 4.7). A failed sign in records only the action and the IP hash.
  module RecordAudit
    METADATA = {
      "sign_up" => { "client" => Session::CLIENTS },
      "sign_in" => { "client" => Session::CLIENTS },
      "sign_in_failed" => {},
      "session_revoked" => {},
      "all_sessions_revoked" => {},
      "password_reset" => {},
      "consent_granted" => { "purpose" => ConsentTexts::PURPOSES },
      "consent_revoked" => { "purpose" => ConsentTexts::PURPOSES }
    }.freeze

    def self.call(action:, ip:, user_ref: nil, metadata: {})
      allowed = METADATA.fetch(action.to_s) { raise ArgumentError, "unknown audit action" }
      metadata = metadata.to_h.transform_keys(&:to_s)
      metadata.each do |field, value|
        raise ArgumentError, "#{action} does not record the field #{field.to_s[/\A[a-z_]{1,32}\z/] || '(refused)'}" unless allowed.key?(field)
        raise ArgumentError, "#{action} records #{field} only from its closed list" unless allowed[field].include?(value)
      end

      AuditEvent.create!(action: action.to_s, user_ref:, metadata:, ip_hmac: ip_hmac(ip), occurred_at: Time.current)
    end

    # A plain hash of an IPv4 address is reversible, so it is keyed (DATABASE_DESIGN.md).
    def self.ip_hmac(ip)
      OpenSSL::HMAC.hexdigest("SHA256", Rails.configuration.x.audit_ip_hmac_key, ip.to_s) if ip.present?
    end
    private_class_method :ip_hmac
  end
end

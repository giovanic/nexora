module Shared
  module Outbox
    # Cheap guard for the rule that payloads carry only identifiers and
    # closed-list values (DOMAIN_MODEL.md): lowercase tokens, UUIDs, numbers,
    # booleans, dates, timestamps, IANA time zones known to TZInfo and flat
    # lists of them. It refuses e-mails, capitalized names and free text, but
    # cannot tell a lowercase name from a token, so publishers still own the rule.
    module PayloadCheck
      TOKEN = /\A[a-z0-9][a-z0-9_.\-]{0,63}\z/
      TIMESTAMP = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{2}:\d{2})\z/
      # Only the shape; the zone must also exist in TZInfo.
      TIME_ZONE = %r{\A[A-Za-z][A-Za-z0-9_+\-]*(/[A-Za-z0-9_+\-]+){0,2}\z}
      MAX_LIST = 32

      def self.call(payload)
        raise InvalidPayload, "payload must be a Hash" unless payload.is_a?(Hash)

        payload.each do |key, value|
          raise InvalidPayload, "payload key must be a lowercase token" unless key.to_s.match?(TOKEN)
          raise InvalidPayload, "payload value for #{key} must be an identifier or a closed-list value" unless allowed?(value)
        end
      end

      def self.allowed?(value, nested: false)
        case value
        when nil, true, false, Integer then true
        when String then value.match?(TOKEN) || value.match?(TIMESTAMP) || time_zone?(value)
        when Array then !nested && value.size <= MAX_LIST && value.all? { |item| allowed?(item, nested: true) }
        else false
        end
      end
      private_class_method :allowed?

      def self.time_zone?(value)
        value.match?(TIME_ZONE) && TZInfo::Timezone.all_identifiers.include?(value)
      end
      private_class_method :time_zone?
    end
  end
end

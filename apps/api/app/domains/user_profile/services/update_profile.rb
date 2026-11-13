module UserProfile
  # Changes only the fields sent. Nothing is saved unless every field is valid.
  module UpdateProfile
    FIELDS = %i[display_name time_zone motivations].freeze

    def self.call(user_id:, attrs:)
      attrs = attrs.to_h.symbolize_keys.slice(*FIELDS)
      invalid = failures(attrs)
      return Api::Errors.new(code: "invalid_time_zone", details: invalid) if invalid.any? { |detail| detail[:field] == "time_zone" }
      return Api::Errors.new(code: "validation_failed", details: invalid) if invalid.any?

      Profile.transaction do
        profile = Profile.lock.find_by(user_id:)
        next :pending unless profile

        attrs[:motivations] = attrs[:motivations].uniq if attrs.key?(:motivations)
        profile.update!(attrs)
        Api.present(profile)
      end
    end

    # Details name the field and the rule, never the submitted value.
    def self.failures(attrs)
      [ name_failure(attrs), zone_failure(attrs), motivations_failure(attrs) ].compact
    end

    def self.name_failure(attrs)
      return unless attrs.key?(:display_name)

      name = attrs[:display_name]
      return if name.nil?
      return { field: "display_name", code: "invalid" } unless name.is_a?(String)

      { field: "display_name", code: "too_long" } if name.length > Profile::MAX_DISPLAY_NAME
    end

    def self.zone_failure(attrs)
      return unless attrs.key?(:time_zone)

      zone = attrs[:time_zone]
      { field: "time_zone", code: "invalid" } unless zone.is_a?(String) && TZInfo::Timezone.all_identifiers.include?(zone)
    end

    def self.motivations_failure(attrs)
      return unless attrs.key?(:motivations)

      list = attrs[:motivations]
      return { field: "motivations", code: "invalid" } unless list.is_a?(Array) && list.all?(String)
      return { field: "motivations", code: "too_long" } if list.size > Profile::MAX_MOTIVATIONS

      { field: "motivations", code: "inclusion" } unless (list - Profile::MOTIVATIONS).empty?
    end

    private_class_method :failures, :name_failure, :zone_failure, :motivations_failure
  end
end

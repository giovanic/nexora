module Goals
  # The person's local day and the window in which a check-in is accepted: yesterday and today.
  module LocalDay
    FORMAT = /\A\d{4}-\d{2}-\d{2}\z/

    # The person's time zone, or UTC while the profile is pending (same rule as Nutrition::MealTime).
    def self.zone_for(user_id)
      ActiveSupport::TimeZone[UserProfile::Api.time_zone(user_id:) || "UTC"] || ActiveSupport::TimeZone["UTC"]
    end

    def self.today(user_id:, now: Time.current) = now.in_time_zone(zone_for(user_id)).to_date

    # [yesterday, today]
    def self.window(user_id:, now: Time.current)
      today = today(user_id:, now:)
      [ today - 1, today ]
    end

    # A Date, or nil when the value is not a valid YYYY-MM-DD.
    def self.parse(value)
      return unless value.is_a?(String) && value.match?(FORMAT)

      Date.iso8601(value)
    rescue ArgumentError
      nil
    end
  end
end

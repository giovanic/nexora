module Nutrition
  # When a meal happened, and the person's day. meal_at comes from the client, so it is held to ISO 8601
  # with a UTC offset and to a window around now: at most 1 day ahead and 30 days back.
  module MealTime
    AHEAD = 1.day
    BEHIND = 30.days
    FORMAT = /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})\z/

    # A Time, or nil when the value is not a string in that format or falls outside the window.
    def self.parse(value, now: Time.current)
      return unless value.is_a?(String) && value.match?(FORMAT)

      time = Time.iso8601(value)
      time if time <= now + AHEAD && time >= now - BEHIND
    rescue ArgumentError
      nil
    end

    # The person's time zone, or UTC while the profile is pending.
    def self.zone_for(user_id)
      ActiveSupport::TimeZone[UserProfile::Api.time_zone(user_id:) || "UTC"] || ActiveSupport::TimeZone["UTC"]
    end

    def self.invalid = { field: "meal_at", code: "invalid" }
  end
end

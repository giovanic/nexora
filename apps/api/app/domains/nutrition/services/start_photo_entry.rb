module Nutrition
  # Starts a meal from a photo: asks FoodAi to authorize the upload (it checks consent and quota
  # for the person's local day), then creates the pending meal and ties the photo to it. The same
  # client_request_id gives back the same meal. A retry after a failure between the two steps
  # finds the authorized photo and finishes the job. Nothing external runs in a transaction.
  module StartPhotoEntry
    def self.call(user_id:, client_request_id:, content_type:, byte_size:, meal_at:)
      parsed = parse(meal_at)
      return Api::Errors.new(code: "validation_failed", details: [ { field: "meal_at", code: "invalid" } ]) unless parsed

      zone = zone_for(user_id)
      day_start = Time.current.in_time_zone(zone).beginning_of_day
      day_end = (day_start + 1.day).beginning_of_day
      authorization = FoodAi::Api.authorize_photo_upload(user_id:, client_request_id:, content_type:, byte_size:, day_start:, day_end:)
      return Api::Errors.new(code: authorization.code, details: authorization.details, retry_at: authorization.retry_at) unless authorization.ok?

      entry = find_or_create(user_id:, client_request_id:, photo_id: authorization.photo_id, meal_at: parsed, local_date: parsed.in_time_zone(zone).to_date)
      FoodAi::Api.link_photo(user_id:, photo_id: authorization.photo_id, food_entry_id: entry.id)
      Api::EntryUpload.new(food_entry_id: entry.id, status: entry.status, upload_url: authorization.upload_url, upload_headers: authorization.upload_headers,
                           expires_at: authorization.expires_at)
    end

    # The person's time zone, or UTC while the profile is pending.
    def self.zone_for(user_id)
      ActiveSupport::TimeZone[UserProfile::Api.time_zone(user_id:) || "UTC"] || ActiveSupport::TimeZone["UTC"]
    end

    def self.parse(value)
      return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)
      return unless value.is_a?(String)

      Time.iso8601(value)
    rescue ArgumentError
      nil
    end

    def self.find_or_create(user_id:, client_request_id:, photo_id:, meal_at:, local_date:)
      FoodEntry.find_by(user_id:, client_request_id:) ||
        FoodEntry.create!(user_id:, client_request_id:, photo_id:, meal_at:, local_date:, source: "photo", status: "pending")
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      # The uniqueness validation can lose the race before the index does.
      FoodEntry.find_by!(user_id:, client_request_id:)
    end
    private_class_method :zone_for, :parse, :find_or_create
  end
end

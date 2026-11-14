module Nutrition
  # The only entry point to Nutrition for other contexts and controllers. It returns Data
  # objects, never models.
  module Api
    USER_DATA_TABLES = %w[food_entries].freeze
    EntryUpload = Data.define(:food_entry_id, :upload_url, :upload_headers, :expires_at) do
      def ok? = true
    end
    EntryInfo = Data.define(:id, :status, :local_date, :meal_at) do
      def ok? = true
    end
    # code as FoodAi::Api::Errors, plus validation_failed for meal_at. retry_at only for
    # analysis_quota_exceeded: the end of the person's local day.
    Errors = Data.define(:code, :details, :retry_at) do
      def initialize(code:, details: [], retry_at: nil) = super
      def ok? = false
    end

    class << self
      # EntryUpload or Errors. meal_at is an ISO 8601 string with offset.
      def start_photo_entry(user_id:, client_request_id:, content_type:, byte_size:, meal_at:)
        StartPhotoEntry.call(user_id:, client_request_id:, content_type:, byte_size:, meal_at:)
      end

      # EntryInfo, or :not_found, also for another person's meal.
      def entry(user_id:, food_entry_id:)
        entry = FoodEntry.find_by(user_id:, id: food_entry_id)
        entry ? EntryInfo.new(id: entry.id, status: entry.status, local_date: entry.local_date, meal_at: entry.meal_at) : :not_found
      end

      def export_user_data(user_id)
        UserData.export(user_id)
      end

      def erase_user_data(user_id)
        UserData.erase(user_id)
      end
    end
  end
end

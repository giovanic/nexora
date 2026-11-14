module Nutrition
  # The only entry point to Nutrition for other contexts and controllers. It returns Data
  # objects, never models.
  module Api
    USER_DATA_TABLES = %w[food_entries food_items].freeze
    # upload_url, upload_headers and expires_at are nil when the photo is past the upload (a repeated request).
    EntryUpload = Data.define(:food_entry_id, :status, :upload_url, :upload_headers, :expires_at) do
      def ok? = true
    end
    # view: the meal as clients show it (EntryView), only from Api.entry.
    EntryInfo = Data.define(:id, :status, :local_date, :meal_at, :view) do
      def initialize(id:, status:, local_date:, meal_at:, view: nil) = super
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

      # EntryInfo (with its view: items, ranges, confidence and, while the photo exists, a signed photo_url),
      # or :not_found, also for another person's meal or a malformed id.
      def entry(user_id:, food_entry_id:)
        return :not_found unless food_entry_id.to_s.match?(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)

        entry = FoodEntry.find_by(user_id:, id: food_entry_id)
        return :not_found unless entry

        view = EntryView.call(entry, photo_url: FoodAi::Api.photo_url(user_id:, photo_id: entry.photo_id))
        EntryInfo.new(id: entry.id, status: entry.status, local_date: entry.local_date, meal_at: entry.meal_at, view:)
      end

      # EntryInfo (now processing), :not_found (also for another person's meal) or Errors:
      # entry_not_analyzable (not pending or failed), or what FoodAi refuses with (not_uploaded,
      # invalid_photo, consent_required, consent_operator_mismatch). A refusal leaves the meal as it was.
      def request_analysis(user_id:, food_entry_id:)
        RequestEntryAnalysis.call(user_id:, food_entry_id:)
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

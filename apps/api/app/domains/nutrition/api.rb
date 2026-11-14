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
    # created: only from create_manual_entry, false when the client_request_id had already made the meal.
    EntryInfo = Data.define(:id, :status, :local_date, :meal_at, :view, :created) do
      def initialize(id:, status:, local_date:, meal_at:, view: nil, created: false) = super
      def ok? = true
    end
    # views: the meals as EntryView shows them. next_cursor is nil on the last page.
    EntryPage = Data.define(:views, :next_cursor) do
      def ok? = true
    end
    # code as FoodAi::Api::Errors, plus validation_failed (details name the fields), entry_not_confirmable and
    # entry_not_editable. retry_at only for analysis_quota_exceeded: the end of the person's local day.
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

        info(entry)
      end

      # EntryInfo (confirmed; also when it already was), :not_found, or Errors entry_not_confirmable
      # (the meal is not analyzed, or has no item).
      def confirm_entry(user_id:, food_entry_id:)
        info_for(ConfirmFoodEntry.call(user_id:, food_entry_id:))
      end

      # changes: a Hash with :grams_likely and/or :catalog_item_id, as sent. EntryInfo of the recalculated
      # meal, :not_found (meal or item, also another person's), or Errors: entry_not_editable, validation_failed.
      def correct_item(user_id:, food_entry_id:, item_id:, changes:)
        info_for(CorrectFoodItem.call(user_id:, food_entry_id:, item_id:, changes:))
      end

      # item: a Hash with :catalog_item_id or :free_text_name, and :grams_likely (:grams_min, :grams_max).
      # Same results as correct_item.
      def add_item(user_id:, food_entry_id:, item:)
        info_for(AddFoodItem.call(user_id:, food_entry_id:, raw: item))
      end

      # EntryInfo of the recalculated meal, :not_found, or Errors entry_not_editable.
      def remove_item(user_id:, food_entry_id:, item_id:)
        info_for(RemoveFoodItem.call(user_id:, food_entry_id:, item_id:))
      end

      # A meal registered by hand: confirmed, no photo, no quota. items: a list of Hashes as add_item takes.
      # meal_at as start_photo_entry. EntryInfo (created says whether it is new) or Errors validation_failed.
      def create_manual_entry(user_id:, client_request_id:, meal_at:, items:)
        result = CreateManualEntry.call(user_id:, client_request_id:, meal_at:, items:)
        return result unless result.is_a?(Array)

        info(result.first, created: result.last)
      end

      # EntryPage or Errors validation_failed (local_date, cursor, per_page). per_page: 20 by default, at most 50.
      def list_entries(user_id:, local_date: nil, cursor: nil, per_page: nil)
        result = ListFoodEntries.call(user_id:, local_date:, cursor:, per_page:)
        return result if result.is_a?(Errors)

        entries = result.fetch(:entries)
        urls = FoodAi::Api.photo_urls(user_id:, photo_ids: entries.map(&:photo_id))
        EntryPage.new(views: entries.map { |entry| EntryView.call(entry, photo_url: urls[entry.photo_id]) }, next_cursor: result.fetch(:next_cursor))
      end

      # :deleted or :not_found. The items go with the meal, then FoodAi erases the photo and the result.
      def delete_entry(user_id:, food_entry_id:)
        DeleteFoodEntry.call(user_id:, food_entry_id:)
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

      private

      def info(entry, created: false)
        entry.reload
        view = EntryView.call(entry, photo_url: FoodAi::Api.photo_url(user_id: entry.user_id, photo_id: entry.photo_id))
        EntryInfo.new(id: entry.id, status: entry.status, local_date: entry.local_date, meal_at: entry.meal_at, view:, created:)
      end

      # A service's meal as EntryInfo; :not_found and Errors as they are.
      def info_for(result)
        result.is_a?(FoodEntry) ? info(result) : result
      end
    end
  end
end

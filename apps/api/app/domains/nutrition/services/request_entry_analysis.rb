module Nutrition
  # Starts the analysis of a meal's uploaded photo. The meal must be the person's (404 otherwise) and
  # pending or failed (409). It moves to processing first, in one conditional update, so two requests
  # cannot both start; then FoodAi checks consent and the object and enqueues. If FoodAi refuses, or
  # enqueueing fails, the meal goes back to where it was.
  module RequestEntryAnalysis
    STARTABLE = %w[pending failed].freeze

    def self.call(user_id:, food_entry_id:)
      entry = FoodEntry.find_by(user_id:, id: food_entry_id)
      return :not_found unless entry
      return conflict unless entry.photo_id && STARTABLE.include?(entry.status)

      previous = entry.status
      return conflict unless FoodEntry.where(id: entry.id, status: previous).update_all(status: "processing", updated_at: Time.current) == 1

      begin
        result = FoodAi::Api.request_analysis(user_id:, photo_id: entry.photo_id, food_entry_id: entry.id)
      rescue StandardError
        revert(entry, previous)
        raise
      end
      return Api::EntryInfo.new(id: entry.id, status: "processing", local_date: entry.local_date, meal_at: entry.meal_at) if result == :enqueued

      revert(entry, previous)
      Api::Errors.new(code: result.code, details: result.details)
    end

    def self.revert(entry, previous)
      FoodEntry.where(id: entry.id, status: "processing").update_all(status: previous, updated_at: Time.current)
    end

    def self.conflict
      Api::Errors.new(code: "entry_not_analyzable")
    end
    private_class_method :revert, :conflict
  end
end

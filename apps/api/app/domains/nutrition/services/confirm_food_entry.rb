module Nutrition
  # The person accepts the analyzed meal as it stands. Only an analyzed meal with an item is confirmed;
  # confirming a confirmed meal changes nothing. The meal is locked, so two requests confirm it once, and
  # food_entry.confirmed (identifier and local date) goes to the outbox in the same transaction.
  # The meal, :not_found (also for another person's meal) or Errors (entry_not_confirmable).
  module ConfirmFoodEntry
    def self.call(user_id:, food_entry_id:)
      FoodEntry.transaction do
        entry = FoodEntry.lock.find_by(user_id:, id: food_entry_id)
        next :not_found unless entry
        next entry if entry.status == "confirmed"
        next Api::Errors.new(code: "entry_not_confirmable") unless entry.status == "analyzed" && entry.visible_items.exists?

        entry.update!(status: "confirmed", confirmed_at: Time.current)
        Shared::Outbox.publish!(name: "food_entry.confirmed", user_id:, payload: { food_entry_id: entry.id, local_date: entry.local_date.iso8601 })
        entry
      end
    end
  end
end

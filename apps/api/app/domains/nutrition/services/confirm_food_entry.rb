module Nutrition
  # The person accepts the analyzed meal as it stands. Only an analyzed meal with an item is confirmed;
  # confirming a confirmed meal changes nothing. The meal is locked, so two requests confirm it once.
  # The meal, :not_found (also for another person's meal) or Errors (entry_not_confirmable).
  module ConfirmFoodEntry
    def self.call(user_id:, food_entry_id:)
      FoodEntry.transaction do
        entry = FoodEntry.lock.find_by(user_id:, id: food_entry_id)
        next :not_found unless entry
        next entry if entry.status == "confirmed"
        next Api::Errors.new(code: "entry_not_confirmable") unless entry.status == "analyzed" && entry.visible_items.exists?

        entry.update!(status: "confirmed", confirmed_at: Time.current)
        entry
      end
    end
  end
end

module Nutrition
  # Deletes the person's meal and its items (all of them, hidden ones too), in one statement, and publishes
  # food_entry.deleted in the same transaction (FoodAi consumes it and erases the photo). Only then
  # FoodAi erases the photo, the object and the model's result: it calls storage, so it runs after the
  # delete is committed and outside any transaction. :deleted or :not_found (also for another person's meal).
  module DeleteFoodEntry
    def self.call(user_id:, food_entry_id:)
      photo_id = FoodEntry.where(user_id:, id: food_entry_id).pick(:photo_id)
      deleted = FoodEntry.transaction do
        next false unless FoodEntry.where(user_id:, id: food_entry_id).delete_all == 1

        # The photo's erasure must not depend on this process surviving: FoodAi consumes this event.
        Shared::Outbox.publish!(name: "food_entry.deleted", user_id:, payload: { food_entry_id:, photo_id: })
        true
      end
      return :not_found unless deleted

      shortcut(user_id:, food_entry_id:, photo_id:)
      :deleted
    end

    # Erases at once what the event would erase a moment later. The meal is already gone, so a failure here
    # must not answer an error: the event does it (only the class of the error is logged).
    def self.shortcut(user_id:, food_entry_id:, photo_id:)
      FoodAi::Api.erase_for_entry(user_id:, food_entry_id:, photo_id:)
    rescue StandardError => error
      Rails.logger.warn("food photo erasure left to the event entry_id=#{food_entry_id} error=#{error.class}")
    end
    private_class_method :shortcut
  end
end

module Nutrition
  # Deletes the person's meal and its items (all of them, hidden ones too), in one statement. Only then
  # FoodAi erases the photo, the object and the model's result: it calls storage, so it runs after the
  # delete is committed and outside any transaction. :deleted or :not_found (also for another person's meal).
  module DeleteFoodEntry
    def self.call(user_id:, food_entry_id:)
      photo_id = FoodEntry.where(user_id:, id: food_entry_id).pick(:photo_id)
      return :not_found unless FoodEntry.where(user_id:, id: food_entry_id).delete_all == 1

      FoodAi::Api.erase_for_entry(user_id:, food_entry_id:, photo_id:)
      :deleted
    end
  end
end

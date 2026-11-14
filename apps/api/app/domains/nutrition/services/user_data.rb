module Nutrition
  # Nutrition's part of account export and deletion, through Shared::DataRegistry.
  # The photo is FoodAi's, and FoodAi exports and erases it.
  module UserData
    def self.export(user_id)
      {
        entries: FoodEntry.where(user_id:).order(:meal_at, :id).map do |entry|
          entry.slice(:id, :source, :status, :result_code, :estimate_partial, :meal_at, :local_date,
                      :calories_min, :calories_likely, :calories_max, :confirmed_at).symbolize_keys
        end
      }
    end

    # Safe to run again.
    def self.erase(user_id)
      FoodEntry.where(user_id:).delete_all
    end
  end
end

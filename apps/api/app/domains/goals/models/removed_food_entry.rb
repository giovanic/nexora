module Goals
  # Marker that a meal was deleted. food_entry_id is the meal's id by value only (no foreign key to Nutrition).
  class RemovedFoodEntry < ApplicationRecord
    self.table_name = "goal_removed_food_entries"
  end
end

module Nutrition
  # Nutrition's part of account export and deletion, through Shared::DataRegistry.
  # The photo is FoodAi's, and FoodAi exports and erases it.
  module UserData
    def self.export(user_id)
      {
        entries: FoodEntry.where(user_id:).includes(:items).order(:meal_at, :id).map do |entry|
          entry.slice(:id, :source, :status, :result_code, :estimate_partial, :meal_at, :local_date,
                      :calories_min, :calories_likely, :calories_max, :confirmed_at).symbolize_keys.merge(
                        items: entry.items.sort_by { |item| [ item.created_at, item.id ] }.map do |item|
                          item.slice(:id, :catalog_item_id, :display_name, :quantity_grams_min, :quantity_grams_likely, :quantity_grams_max,
                                     :household_measure, :calories_min, :calories_likely, :calories_max, :protein_g_min, :protein_g_likely,
                                     :protein_g_max, :carbs_g_min, :carbs_g_likely, :carbs_g_max, :fat_g_min, :fat_g_likely, :fat_g_max,
                                     :confidence, :origin, :corrected_from_item_id, :nutrition_source_ref, :hidden_at, :hidden_reason).symbolize_keys
                        end
                      )
        end
      }
    end

    # Items go with their meals (ON DELETE CASCADE). Safe to run again.
    def self.erase(user_id)
      FoodEntry.where(user_id:).delete_all
    end
  end
end

# A corrected item is replaced by a new one, and a removed item leaves the meal, but neither row is
# deleted: the person's history of the meal stays. hidden_at and hidden_reason say why an item is not
# shown. A correction (corrected_from_item_id) is always an item the person made.
#
# The history (newest day first, then newest meal, 20 per page, by cursor) orders by local_date, meal_at and
# id, so its index carries meal_at: the old index on (user_id, local_date, id) served no other query.
class AddHiddenToFoodItems < ActiveRecord::Migration[8.1]
  def change
    add_column :food_items, :hidden_at, :datetime
    add_column :food_items, :hidden_reason, :string
    add_check_constraint :food_items, "(hidden_at IS NULL) = (hidden_reason IS NULL)", name: "food_items_hidden_pair"
    add_check_constraint :food_items, "hidden_reason IS NULL OR hidden_reason IN ('corrected', 'removed')", name: "food_items_hidden_reason_known"
    add_check_constraint :food_items, "corrected_from_item_id IS NULL OR (origin = 'user' AND corrected_from_item_id <> id)",
                         name: "food_items_correction_is_the_persons"

    remove_index :food_entries, %i[user_id local_date id], order: { local_date: :desc, id: :desc }, name: "index_food_entries_on_user_and_local_date"
    add_index :food_entries, %i[user_id local_date meal_at id], order: { local_date: :desc, meal_at: :desc, id: :desc },
                                                                name: "index_food_entries_on_user_and_history"
  end
end

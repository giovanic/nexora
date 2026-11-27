# Marker of a deleted meal (Goals), so a food_entry.confirmed delivered after its food_entry.deleted adds no check-in.
# food_entry_id is a plain uuid, not a foreign key: Goals never references Nutrition's tables. user_id cascades only
# on a physical delete of users; account erasure (users is soft-deleted) removes the markers in Goals::UserData. The unique index serves the confirmation consumer's lookup and the idempotent write.
# The index on created_at serves the daily retention job, which deletes markers older than 30 days in batches.
class CreateGoalRemovedFoodEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :goal_removed_food_entries, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.uuid :food_entry_id, null: false
      t.datetime :created_at, null: false
    end
    add_index :goal_removed_food_entries, %i[user_id food_entry_id], unique: true, name: "index_goal_removed_food_entries_on_user_and_meal"
    add_index :goal_removed_food_entries, :created_at, name: "index_goal_removed_food_entries_on_created_at"
  end
end

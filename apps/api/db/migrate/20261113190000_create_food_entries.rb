# A meal (Nutrition). photo_id is a plain uuid reference to food_photos, not a foreign key:
# domains never join each other's tables, and the photo goes away after the retention period.
# user_id references users, which are anonymized and never deleted.
class CreateFoodEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :food_entries, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: false
      t.string :source, null: false, default: "photo"
      t.string :status, null: false, default: "pending"
      t.uuid :photo_id
      t.string :result_code
      t.boolean :estimate_partial, null: false, default: false
      t.datetime :meal_at, null: false
      t.date :local_date, null: false
      t.integer :calories_min
      t.integer :calories_likely
      t.integer :calories_max
      t.datetime :confirmed_at
      t.string :client_request_id, null: false
      t.timestamps

      t.check_constraint "source IN ('photo', 'manual')", name: "food_entries_source_known"
      t.check_constraint "status IN ('pending', 'processing', 'analyzed', 'failed', 'confirmed')", name: "food_entries_status_known"
      t.check_constraint "result_code IS NULL OR result_code IN ('no_food', 'unreadable')", name: "food_entries_result_code_known"
      t.check_constraint "(calories_min IS NULL AND calories_likely IS NULL AND calories_max IS NULL) OR " \
                         "(calories_min IS NOT NULL AND calories_likely IS NOT NULL AND calories_max IS NOT NULL " \
                         "AND calories_min <= calories_likely AND calories_likely <= calories_max)",
                         name: "food_entries_calories_range"
    end
    add_index :food_entries, %i[user_id client_request_id], unique: true
    add_index :food_entries, %i[user_id local_date id], order: { local_date: :desc, id: :desc }, name: "index_food_entries_on_user_and_local_date"
    add_index :food_entries, :photo_id
  end
end

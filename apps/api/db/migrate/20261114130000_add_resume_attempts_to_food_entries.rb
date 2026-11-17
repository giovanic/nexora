# Counts how many times StuckEntriesJob resumed a meal that stayed in processing. After 3 the meal fails.
# A new analysis request resets it. Reversible.
class AddResumeAttemptsToFoodEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :food_entries, :resume_attempts, :integer, default: 0, null: false
    add_check_constraint :food_entries, "resume_attempts >= 0", name: "food_entries_resume_attempts_non_negative"
  end
end

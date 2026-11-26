# A day marked on a goal (Goals). source_ref is a plain uuid (the food entry), not a foreign key: domains never join
# each other's tables. user_id references users, which are anonymized and never deleted.
class CreateGoalCheckIns < ActiveRecord::Migration[8.1]
  def change
    create_table :goal_check_ins, id: :uuid do |t|
      t.references :goal, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :user, type: :uuid, null: false, foreign_key: true, index: false
      t.date :local_date, null: false
      t.string :source, null: false
      t.uuid :source_ref
      t.datetime :checked_at, null: false
      t.timestamps

      t.check_constraint "source IN ('manual', 'food_entry')", name: "goal_check_ins_source_known"
      t.check_constraint "(source = 'manual') = (source_ref IS NULL)", name: "goal_check_ins_ref_matches_source"
    end
    add_index :goal_check_ins, %i[goal_id local_date], unique: true, where: "source = 'manual'", name: "index_goal_check_ins_one_manual_per_day"
    add_index :goal_check_ins, %i[goal_id source source_ref], unique: true, where: "source_ref IS NOT NULL",
                                                               name: "index_goal_check_ins_one_per_source_ref"
    add_index :goal_check_ins, %i[user_id local_date], order: { local_date: :desc }, name: "index_goal_check_ins_on_user_and_local_date"
    add_index :goal_check_ins, %i[goal_id local_date], order: { local_date: :desc }, name: "index_goal_check_ins_on_goal_and_local_date"
  end
end

# A check-in belongs to the person who owns its goal: the database refuses a user_id that differs from the goal's.
# The composite foreign key replaces the plain one on goal_id and keeps the cascade on delete.
class TieGoalCheckInOwnerToGoalOwner < ActiveRecord::Migration[8.1]
  def change
    add_index :goals, %i[id user_id], unique: true, name: "index_goals_on_id_and_user_id"
    remove_foreign_key :goal_check_ins, :goals, column: :goal_id, on_delete: :cascade
    add_foreign_key :goal_check_ins, :goals, column: %i[goal_id user_id], primary_key: %i[id user_id], on_delete: :cascade,
                                              name: "goal_check_ins_goal_owner"
  end
end

# A daily habit goal (Goals). The closed list of types lives in the database too, so no path can store a calorie,
# weight, fasting or compensation goal. weekly cadence and a target above 1 arrive in 05.2 with a new migration.
class CreateGoals < ActiveRecord::Migration[8.1]
  def change
    create_table :goals, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: false
      t.string :goal_type, null: false
      t.string :cadence, null: false, default: "daily"
      t.integer :target, null: false, default: 1
      t.string :rule_version, null: false
      t.string :status, null: false, default: "active"
      t.date :starts_on, null: false
      t.date :ends_on
      t.datetime :paused_at
      t.timestamps

      t.check_constraint "goal_type IN ('log_meals', 'include_fruits_vegetables', 'drink_water', 'sleep_routine', 'planned_workout')",
                         name: "goals_goal_type_allowed"
      t.check_constraint "cadence = 'daily'", name: "goals_cadence_daily"
      t.check_constraint "target = 1", name: "goals_target_one"
      t.check_constraint "status IN ('active', 'paused', 'ended')", name: "goals_status_known"
      t.check_constraint "status <> 'ended' OR ends_on IS NOT NULL", name: "goals_ended_has_end"
    end
    add_index :goals, %i[user_id goal_type], unique: true, where: "status IN ('active', 'paused')", name: "index_goals_one_live_per_type"
    add_index :goals, %i[user_id status]
  end
end

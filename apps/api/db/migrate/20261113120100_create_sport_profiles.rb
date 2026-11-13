# One row per period a person practices a sport at a level. Changing the level
# ends the row (ended_at) and starts another, so the history is never rewritten.
class CreateSportProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :sport_profiles, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: false
      t.string :sport, null: false
      t.string :level, null: false
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.timestamps

      t.check_constraint "sport IN ('running', 'walking', 'cycling', 'strength', 'swimming', 'other')", name: "sport_profiles_sport_known"
      t.check_constraint "level IN ('beginner', 'intermediate', 'advanced')", name: "sport_profiles_level_known"
      t.check_constraint "ended_at IS NULL OR ended_at >= started_at", name: "sport_profiles_period_ordered"
    end

    # At most one active row per sport.
    add_index :sport_profiles, %i[user_id sport], unique: true, where: "ended_at IS NULL", name: "index_sport_profiles_active"
    add_index :sport_profiles, %i[user_id started_at]
  end
end

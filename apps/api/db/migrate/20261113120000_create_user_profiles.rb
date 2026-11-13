# Profile of each account (UserProfile), one row per user. display_name is
# encrypted non-deterministically by the model. The row is created by the
# user.registered consumer. The foreign key to users holds because the account
# is anonymized and never deleted (design 4.4).
class CreateUserProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :user_profiles, primary_key: :user_id, id: :uuid, default: nil do |t|
      t.string :display_name
      t.string :time_zone, null: false
      t.string :units, null: false, default: "metric"
      t.jsonb :notification_preferences, null: false, default: {}
      t.text :motivations, array: true, null: false, default: []
      t.timestamps

      t.check_constraint "units IN ('metric')", name: "user_profiles_units_known"
      t.check_constraint "cardinality(motivations) <= 4", name: "user_profiles_motivations_max"
      t.check_constraint "motivations <@ ARRAY['start_caring', 'training_consistency', 'understand_food', 'track_progress']::text[]",
                         name: "user_profiles_motivations_known"
      t.check_constraint "jsonb_typeof(notification_preferences) = 'object'", name: "user_profiles_preferences_object"
    end

    add_foreign_key :user_profiles, :users
  end
end

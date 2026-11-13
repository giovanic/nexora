# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_13_140000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "account_deletions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.datetime "requested_at", null: false
    t.text "pending_contexts", default: [], null: false, array: true
    t.datetime "completed_at"
    t.index ["requested_at"], name: "index_account_deletions_unfinished", where: "(completed_at IS NULL)"
    t.index ["user_id"], name: "index_account_deletions_on_user_id", unique: true
    t.check_constraint "array_to_string(pending_contexts, ','::text) ~ '^([a-z][a-z_]*(,|$))*$'::text", name: "account_deletions_contexts_format"
    t.check_constraint "completed_at IS NULL OR cardinality(pending_contexts) = 0", name: "account_deletions_completed_when_empty"
  end

  create_table "audit_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_ref"
    t.string "action", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "ip_hmac"
    t.datetime "occurred_at", null: false
    t.index ["user_ref", "occurred_at"], name: "index_audit_events_on_user_ref_and_occurred_at"
    t.check_constraint "action::text ~ '^[a-z][a-z_]*$'::text", name: "audit_events_action_format"
    t.check_constraint "jsonb_typeof(metadata) = 'object'::text", name: "audit_events_metadata_object"
  end

  create_table "consent_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "purpose", null: false
    t.integer "text_version", null: false
    t.string "action", null: false
    t.string "source"
    t.datetime "occurred_at", null: false
    t.index ["user_id", "purpose", "occurred_at"], name: "index_consent_records_on_user_id_and_purpose_and_occurred_at", unique: true, order: { occurred_at: :desc }
    t.check_constraint "action::text = ANY (ARRAY['granted'::text, 'revoked'::text])", name: "consent_records_action_known"
    t.check_constraint "purpose::text = ANY (ARRAY['health_data'::text, 'food_photo_ai'::text, 'strava_integration'::text, 'usage_metrics'::text])", name: "consent_records_purpose_known"
    t.check_constraint "source::text = ANY (ARRAY['web'::text, 'mobile'::text])", name: "consent_records_source_known"
    t.check_constraint "text_version > 0", name: "consent_records_text_version_positive"
  end

  create_table "consumed_events", primary_key: ["consumer", "event_id"], force: :cascade do |t|
    t.string "consumer", null: false
    t.uuid "event_id", null: false
    t.datetime "consumed_at", null: false
    t.index ["event_id"], name: "index_consumed_events_on_event_id"
  end

  create_table "outbox_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.integer "version", default: 1, null: false
    t.uuid "user_id"
    t.string "correlation_id"
    t.jsonb "payload", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.datetime "published_at"
    t.integer "attempts", default: 0, null: false
    t.datetime "next_attempt_at"
    t.datetime "dead_at"
    t.index ["occurred_at"], name: "index_outbox_events_pending", where: "((published_at IS NULL) AND (dead_at IS NULL))"
    t.index ["user_id"], name: "index_outbox_events_on_user_id"
    t.check_constraint "attempts >= 0", name: "outbox_events_attempts_not_negative"
    t.check_constraint "jsonb_typeof(payload) = 'object'::text", name: "outbox_events_payload_object"
    t.check_constraint "name::text ~ '^[a-z][a-z_]*(\\.[a-z][a-z_]*)+$'::text", name: "outbox_events_name_format"
    t.check_constraint "version >= 1", name: "outbox_events_version_positive"
  end

  create_table "sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "token_digest", null: false
    t.string "client", null: false
    t.string "device_label"
    t.datetime "last_used_at", null: false
    t.datetime "idle_expires_at", null: false
    t.datetime "absolute_expires_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_sessions_on_token_digest", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
    t.check_constraint "client::text = ANY (ARRAY['web'::text, 'mobile'::text])", name: "sessions_client_known"
    t.check_constraint "idle_expires_at <= absolute_expires_at", name: "sessions_idle_within_absolute"
  end

  create_table "sport_profiles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "sport", null: false
    t.string "level", null: false
    t.datetime "started_at", null: false
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "sport"], name: "index_sport_profiles_active", unique: true, where: "(ended_at IS NULL)"
    t.index ["user_id", "started_at"], name: "index_sport_profiles_on_user_id_and_started_at"
    t.check_constraint "ended_at IS NULL OR ended_at >= started_at", name: "sport_profiles_period_ordered"
    t.check_constraint "level::text = ANY (ARRAY['beginner'::text, 'intermediate'::text, 'advanced'::text])", name: "sport_profiles_level_known"
    t.check_constraint "sport::text = ANY (ARRAY['running'::text, 'walking'::text, 'cycling'::text, 'strength'::text, 'swimming'::text, 'other'::text])", name: "sport_profiles_sport_known"
  end

  create_table "user_profiles", primary_key: "user_id", id: :uuid, default: nil, force: :cascade do |t|
    t.string "display_name"
    t.string "time_zone", null: false
    t.string "units", default: "metric", null: false
    t.jsonb "notification_preferences", default: {}, null: false
    t.text "motivations", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.check_constraint "cardinality(motivations) <= 4", name: "user_profiles_motivations_max"
    t.check_constraint "jsonb_typeof(notification_preferences) = 'object'::text", name: "user_profiles_preferences_object"
    t.check_constraint "motivations <@ ARRAY['start_caring'::text, 'training_consistency'::text, 'understand_food'::text, 'track_progress'::text]", name: "user_profiles_motivations_known"
    t.check_constraint "units::text = 'metric'::text", name: "user_profiles_units_known"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "adult_confirmed_at", null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "account_deletions", "users"
  add_foreign_key "consent_records", "users"
  add_foreign_key "consumed_events", "outbox_events", column: "event_id", on_delete: :cascade
  add_foreign_key "sessions", "users"
  add_foreign_key "sport_profiles", "users"
  add_foreign_key "user_profiles", "users"
end

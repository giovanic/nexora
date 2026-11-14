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

ActiveRecord::Schema[8.1].define(version: 2026_11_14_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

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

  create_table "ai_usage_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "analysis_id"
    t.uuid "user_id"
    t.string "provider", null: false
    t.string "model", null: false
    t.integer "input_tokens", default: 0, null: false
    t.integer "output_tokens", default: 0, null: false
    t.decimal "cost_usd", precision: 12, scale: 8, default: "0.0", null: false
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["analysis_id"], name: "index_ai_usage_records_on_analysis_id"
    t.index ["occurred_at"], name: "index_ai_usage_records_on_occurred_at"
    t.index ["user_id", "occurred_at"], name: "index_ai_usage_records_on_user_id_and_occurred_at"
    t.check_constraint "input_tokens >= 0 AND output_tokens >= 0 AND cost_usd >= 0::numeric", name: "ai_usage_records_non_negative"
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

  create_table "food_analysis_results", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "food_entry_id"
    t.uuid "user_id", null: false
    t.uuid "photo_id", null: false
    t.string "provider", null: false
    t.string "model", null: false
    t.string "prompt_version", null: false
    t.string "schema_version", null: false
    t.string "status", default: "running", null: false
    t.jsonb "raw_response"
    t.string "error_code"
    t.datetime "started_at", null: false
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["food_entry_id"], name: "index_food_analysis_results_on_food_entry_id"
    t.index ["photo_id", "prompt_version"], name: "index_food_analysis_results_one_live_run", unique: true, where: "((status)::text <> ALL ((ARRAY['failed'::character varying, 'cancelled'::character varying])::text[]))"
    t.index ["photo_id"], name: "index_food_analysis_results_on_photo_id"
    t.index ["prompt_version", "status"], name: "index_food_analysis_results_on_prompt_and_status"
    t.index ["user_id", "started_at"], name: "index_food_analysis_results_on_user_and_started_at"
    t.check_constraint "error_code IS NULL OR (error_code::text = ANY (ARRAY['timeout'::character varying, 'rate_limited'::character varying, 'provider_unavailable'::character varying, 'bad_request'::character varying, 'unauthorized'::character varying, 'model_unavailable'::character varying, 'unsupported_model'::character varying, 'not_an_object'::character varying, 'missing_field'::character varying, 'unexpected_field'::character varying, 'wrong_type'::character varying, 'out_of_range'::character varying, 'too_many_items'::character varying, 'invalid_text'::character varying, 'unknown_value'::character varying, 'forbidden_field'::character varying, 'refusal'::character varying, 'consent_revoked'::character varying, 'photo_missing'::character varying, 'invalid_encoding'::character varying, 'duplicate_value'::character varying, 'missing_usage'::character varying, 'invalid_photo'::character varying, 'internal_error'::character varying]::text[]))", name: "food_analysis_results_error_code_known"
    t.check_constraint "status::text = ANY (ARRAY['running'::character varying, 'succeeded'::character varying, 'no_food'::character varying, 'unreadable'::character varying, 'failed'::character varying, 'cancelled'::character varying]::text[])", name: "food_analysis_results_status_known"
  end

  create_table "food_catalog", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "source", null: false
    t.string "source_version", null: false
    t.string "source_item_id", null: false
    t.string "license", null: false
    t.string "name", null: false
    t.string "name_pt", null: false
    t.string "name_search", null: false
    t.string "kind", null: false
    t.jsonb "nutrients_per_100g", default: {}, null: false
    t.string "review"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name_search"], name: "index_food_catalog_on_name_search_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["source", "source_version", "source_item_id"], name: "index_food_catalog_on_source_release_item", unique: true
    t.check_constraint "kind::text = ANY (ARRAY['ingredient'::text, 'composition'::text])", name: "food_catalog_kind_known"
    t.check_constraint "length(btrim(license::text)) > 0", name: "food_catalog_license_present"
    t.check_constraint "source::text = ANY (ARRAY['usda_fdc'::text, 'project'::text])", name: "food_catalog_source_known"
  end

  create_table "food_compositions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "catalog_item_id", null: false
    t.uuid "ingredient_catalog_item_id", null: false
    t.decimal "grams_per_100g", precision: 7, scale: 2, null: false
    t.string "notes"
    t.index ["catalog_item_id", "ingredient_catalog_item_id"], name: "index_food_compositions_on_item_and_ingredient", unique: true
    t.index ["ingredient_catalog_item_id"], name: "index_food_compositions_on_ingredient_catalog_item_id"
    t.check_constraint "grams_per_100g > 0::numeric AND grams_per_100g <= 100::numeric", name: "food_compositions_grams_in_range"
  end

  create_table "food_entries", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "source", default: "photo", null: false
    t.string "status", default: "pending", null: false
    t.uuid "photo_id"
    t.string "result_code"
    t.boolean "estimate_partial", default: false, null: false
    t.datetime "meal_at", null: false
    t.date "local_date", null: false
    t.decimal "calories_min", precision: 12, scale: 4
    t.decimal "calories_likely", precision: 12, scale: 4
    t.decimal "calories_max", precision: 12, scale: 4
    t.datetime "confirmed_at"
    t.string "client_request_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["photo_id"], name: "index_food_entries_on_photo_id"
    t.index ["user_id", "client_request_id"], name: "index_food_entries_on_user_id_and_client_request_id", unique: true
    t.index ["user_id", "local_date", "meal_at", "id"], name: "index_food_entries_on_user_and_history", order: { local_date: :desc, meal_at: :desc, id: :desc }
    t.check_constraint "calories_min IS NULL AND calories_likely IS NULL AND calories_max IS NULL OR calories_min IS NOT NULL AND calories_likely IS NOT NULL AND calories_max IS NOT NULL AND calories_min::numeric <= calories_likely::numeric AND calories_likely::numeric <= calories_max::numeric", name: "food_entries_calories_range"
    t.check_constraint "result_code IS NULL OR (result_code::text = ANY (ARRAY['no_food'::character varying, 'unreadable'::character varying]::text[]))", name: "food_entries_result_code_known"
    t.check_constraint "source::text = ANY (ARRAY['photo'::character varying, 'manual'::character varying]::text[])", name: "food_entries_source_known"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'processing'::character varying, 'analyzed'::character varying, 'failed'::character varying, 'confirmed'::character varying]::text[])", name: "food_entries_status_known"
  end

  create_table "food_items", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "food_entry_id", null: false
    t.uuid "catalog_item_id"
    t.string "display_name", null: false
    t.decimal "quantity_grams_min", precision: 8, scale: 2, null: false
    t.decimal "quantity_grams_likely", precision: 8, scale: 2, null: false
    t.decimal "quantity_grams_max", precision: 8, scale: 2, null: false
    t.string "household_measure"
    t.decimal "calories_min", precision: 12, scale: 4
    t.decimal "calories_likely", precision: 12, scale: 4
    t.decimal "calories_max", precision: 12, scale: 4
    t.decimal "protein_g_min", precision: 12, scale: 4
    t.decimal "protein_g_likely", precision: 12, scale: 4
    t.decimal "protein_g_max", precision: 12, scale: 4
    t.decimal "carbs_g_min", precision: 12, scale: 4
    t.decimal "carbs_g_likely", precision: 12, scale: 4
    t.decimal "carbs_g_max", precision: 12, scale: 4
    t.decimal "fat_g_min", precision: 12, scale: 4
    t.decimal "fat_g_likely", precision: 12, scale: 4
    t.decimal "fat_g_max", precision: 12, scale: 4
    t.decimal "confidence", precision: 4, scale: 3
    t.boolean "hidden_ingredients_possible", default: false, null: false
    t.string "origin", default: "ai", null: false
    t.uuid "corrected_from_item_id"
    t.jsonb "nutrition_source_ref"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "hidden_at"
    t.string "hidden_reason"
    t.index ["food_entry_id"], name: "index_food_items_on_food_entry_id"
    t.check_constraint "(hidden_at IS NULL) = (hidden_reason IS NULL)", name: "food_items_hidden_pair"
    t.check_constraint "calories_min IS NULL AND calories_likely IS NULL AND calories_max IS NULL OR calories_min IS NOT NULL AND calories_likely IS NOT NULL AND calories_max IS NOT NULL AND calories_min <= calories_likely AND calories_likely <= calories_max", name: "food_items_calories_range"
    t.check_constraint "carbs_g_min IS NULL AND carbs_g_likely IS NULL AND carbs_g_max IS NULL OR carbs_g_min IS NOT NULL AND carbs_g_likely IS NOT NULL AND carbs_g_max IS NOT NULL AND carbs_g_min <= carbs_g_likely AND carbs_g_likely <= carbs_g_max", name: "food_items_carbs_g_range"
    t.check_constraint "confidence IS NULL OR confidence >= 0::numeric AND confidence <= 1::numeric", name: "food_items_confidence_range"
    t.check_constraint "corrected_from_item_id IS NULL OR origin::text = 'user'::text AND corrected_from_item_id <> id", name: "food_items_correction_is_the_persons"
    t.check_constraint "fat_g_min IS NULL AND fat_g_likely IS NULL AND fat_g_max IS NULL OR fat_g_min IS NOT NULL AND fat_g_likely IS NOT NULL AND fat_g_max IS NOT NULL AND fat_g_min <= fat_g_likely AND fat_g_likely <= fat_g_max", name: "food_items_fat_g_range"
    t.check_constraint "hidden_reason IS NULL OR (hidden_reason::text = ANY (ARRAY['corrected'::character varying, 'removed'::character varying]::text[]))", name: "food_items_hidden_reason_known"
    t.check_constraint "origin::text = ANY (ARRAY['ai'::character varying, 'user'::character varying]::text[])", name: "food_items_origin_known"
    t.check_constraint "protein_g_min IS NULL AND protein_g_likely IS NULL AND protein_g_max IS NULL OR protein_g_min IS NOT NULL AND protein_g_likely IS NOT NULL AND protein_g_max IS NOT NULL AND protein_g_min <= protein_g_likely AND protein_g_likely <= protein_g_max", name: "food_items_protein_g_range"
    t.check_constraint "quantity_grams_min > 0::numeric AND quantity_grams_min <= quantity_grams_likely AND quantity_grams_likely <= quantity_grams_max", name: "food_items_grams_range"
  end

  create_table "food_photos", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "food_entry_id"
    t.string "client_request_id", null: false
    t.string "object_key", null: false
    t.string "content_type", null: false
    t.integer "byte_size"
    t.string "status", default: "awaiting_upload", null: false
    t.datetime "authorized_at", null: false
    t.datetime "analyzed_at"
    t.datetime "deleted_at"
    t.datetime "quota_refunded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["food_entry_id"], name: "index_food_photos_on_food_entry_id"
    t.index ["object_key"], name: "index_food_photos_on_object_key", unique: true
    t.index ["status", "analyzed_at"], name: "index_food_photos_on_status_and_analyzed_at"
    t.index ["status", "authorized_at"], name: "index_food_photos_on_status_and_authorized_at"
    t.index ["user_id", "authorized_at"], name: "index_food_photos_on_user_and_authorized_at"
    t.index ["user_id", "client_request_id"], name: "index_food_photos_on_user_id_and_client_request_id", unique: true
    t.check_constraint "status::text = ANY (ARRAY['awaiting_upload'::character varying, 'stored'::character varying, 'deleted'::character varying]::text[])", name: "food_photos_status_known"
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

  create_table "prompt_versions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "version", null: false
    t.string "schema_version", null: false
    t.string "body_ref", null: false
    t.datetime "activated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["version"], name: "index_prompt_versions_on_version", unique: true
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
  add_foreign_key "ai_usage_records", "food_analysis_results", column: "analysis_id", on_delete: :nullify
  add_foreign_key "ai_usage_records", "users"
  add_foreign_key "consent_records", "users"
  add_foreign_key "consumed_events", "outbox_events", column: "event_id", on_delete: :cascade
  add_foreign_key "food_analysis_results", "food_photos", column: "photo_id", on_delete: :cascade
  add_foreign_key "food_analysis_results", "users"
  add_foreign_key "food_compositions", "food_catalog", column: "catalog_item_id", on_delete: :cascade
  add_foreign_key "food_compositions", "food_catalog", column: "ingredient_catalog_item_id"
  add_foreign_key "food_entries", "users"
  add_foreign_key "food_items", "food_entries", on_delete: :cascade
  add_foreign_key "food_photos", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "sport_profiles", "users"
  add_foreign_key "user_profiles", "users"
end

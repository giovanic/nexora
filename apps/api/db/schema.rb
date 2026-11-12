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

ActiveRecord::Schema[8.1].define(version: 2026_11_11_120100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  add_foreign_key "consumed_events", "outbox_events", column: "event_id", on_delete: :cascade
end

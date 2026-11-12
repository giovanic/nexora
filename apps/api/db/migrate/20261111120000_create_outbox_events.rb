# Domain events written in the same transaction as the change they describe
# (ADR 0004). The payload holds only identifiers and closed-list values.
class CreateOutboxEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :outbox_events, id: :uuid do |t|
      t.string :name, null: false
      t.integer :version, null: false, default: 1
      # No foreign key: users belongs to Identity, and shared references no context.
      t.uuid :user_id
      t.string :correlation_id
      t.jsonb :payload, null: false, default: {}
      t.datetime :occurred_at, null: false
      t.datetime :published_at
      t.integer :attempts, null: false, default: 0
      t.datetime :next_attempt_at
      t.datetime :dead_at

      t.check_constraint "name ~ '^[a-z][a-z_]*(\\.[a-z][a-z_]*)+$'", name: "outbox_events_name_format"
      t.check_constraint "version >= 1", name: "outbox_events_version_positive"
      t.check_constraint "attempts >= 0", name: "outbox_events_attempts_not_negative"
      t.check_constraint "jsonb_typeof(payload) = 'object'", name: "outbox_events_payload_object"
    end

    # The publisher picks pending events in order; reconciliation reads the old ones.
    add_index :outbox_events, :occurred_at, where: "published_at IS NULL AND dead_at IS NULL", name: "index_outbox_events_pending"
    # Account deletion erases a user's events, and the discard rule looks them up.
    add_index :outbox_events, :user_id
  end
end

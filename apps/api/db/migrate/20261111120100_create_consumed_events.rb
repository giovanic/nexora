# One row per consumer and event, written in the same transaction as the
# consumer's effect. The primary key is what makes consumers idempotent.
class CreateConsumedEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :consumed_events, primary_key: %i[consumer event_id] do |t|
      t.string :consumer, null: false
      t.uuid :event_id, null: false
      t.datetime :consumed_at, null: false
    end

    # Deleting an event, on account deletion or retention, removes its rows here.
    add_foreign_key :consumed_events, :outbox_events, column: :event_id, on_delete: :cascade
    add_index :consumed_events, :event_id
  end
end

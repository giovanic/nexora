# Append-only trail of sensitive actions (Identity). Metadata follows a closed
# list per action, and holds no e-mail, token or free text. user_ref is not a
# foreign key: it outlives the anonymized account (design 4.4).
class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events, id: :uuid do |t|
      t.uuid :user_ref
      t.string :action, null: false
      t.jsonb :metadata, null: false, default: {}
      t.string :ip_hmac
      t.datetime :occurred_at, null: false

      t.check_constraint "action ~ '^[a-z][a-z_]*$'", name: "audit_events_action_format"
      t.check_constraint "jsonb_typeof(metadata) = 'object'", name: "audit_events_metadata_object"
    end

    # Export lists a user's trail in order.
    add_index :audit_events, %i[user_ref occurred_at]
  end
end

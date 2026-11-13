# Device sessions (Identity). Only the SHA-256 digest of the token is stored.
class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.string :client, null: false
      t.string :device_label
      t.datetime :last_used_at, null: false
      t.datetime :idle_expires_at, null: false
      t.datetime :absolute_expires_at, null: false
      t.datetime :revoked_at
      t.timestamps

      t.check_constraint "client::text IN ('web'::text, 'mobile'::text)", name: "sessions_client_known"
      t.check_constraint "idle_expires_at <= absolute_expires_at", name: "sessions_idle_within_absolute"
      t.check_constraint "char_length(device_label) <= 100", name: "sessions_device_label_length"
    end

    # Every authenticated request looks the session up by its token digest.
    add_index :sessions, :token_digest, unique: true
  end
end

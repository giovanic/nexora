# Consent per purpose (Identity), append-only: every grant and revoke stays as
# history, and the current state is the latest record. Purposes and actions are
# closed lists. The rows outlive the anonymized account, linked to the same
# UUID (design 4.4), so the foreign key holds.
class CreateConsentRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :consent_records, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: false
      t.string :purpose, null: false
      t.integer :text_version, null: false
      t.string :action, null: false
      t.string :source
      t.datetime :occurred_at, null: false

      t.check_constraint "purpose::text IN ('health_data'::text, 'food_photo_ai'::text, 'strava_integration'::text, 'usage_metrics'::text)",
                         name: "consent_records_purpose_known"
      t.check_constraint "action::text IN ('granted'::text, 'revoked'::text)", name: "consent_records_action_known"
      t.check_constraint "source::text IN ('web'::text, 'mobile'::text)", name: "consent_records_source_known"
      t.check_constraint "text_version > 0", name: "consent_records_text_version_positive"
    end

    # The current state is the latest record of a purpose. Being unique, it
    # also refuses two records of a purpose in the same instant.
    add_index :consent_records, %i[user_id purpose occurred_at], order: { occurred_at: :desc }, unique: true
  end
end

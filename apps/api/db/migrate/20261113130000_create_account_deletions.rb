# Account deletions (Identity, design 4.4). One row per account, kept after the
# erasure as the record for backup restores: only the UUID, the dates and the
# contexts still to erase, which are registry names, never free text.
class CreateAccountDeletions < ActiveRecord::Migration[8.1]
  def change
    create_table :account_deletions, id: :uuid do |t|
      # Unique: asking twice, even at once, never starts a second deletion.
      t.references :user, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.datetime :requested_at, null: false
      t.text :pending_contexts, array: true, null: false, default: []
      t.datetime :completed_at

      t.check_constraint "array_to_string(pending_contexts, ',') ~ '^([a-z][a-z_]*(,|$))*$'", name: "account_deletions_contexts_format"
      t.check_constraint "completed_at IS NULL OR cardinality(pending_contexts) = 0", name: "account_deletions_completed_when_empty"
    end

    # DeletionDeadlineJob reads the unfinished ones every hour.
    add_index :account_deletions, :requested_at, where: "completed_at IS NULL", name: "index_account_deletions_unfinished"
  end
end

# Accounts (Identity). The e-mail is encrypted deterministically after being
# normalized, so the unique index works on the ciphertext (design 4.2).
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      # No account without the adult declaration (ADR 0010). It does not prove age.
      t.datetime :adult_confirmed_at, null: false
      t.datetime :deleted_at
      t.timestamps
    end

    # Sign up and sign in look the account up by e-mail.
    add_index :users, :email, unique: true
  end
end

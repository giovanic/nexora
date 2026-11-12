require "rails_helper"

# Every table holding user data must be exported and erased with the account.
# A table counts when it has a user_id column, and `users` always counts.
RSpec.describe "data registry coverage" do
  let(:connection) { ActiveRecord::Base.connection }

  it "registers every table with user data" do
    missing = Shared::DataRegistry.unregistered_tables(connection)

    expect(missing).to eq([]), "Register these tables in Shared::DataRegistry, with an exporter and an eraser: #{missing.join(', ')}"
  end

  # PostgreSQL runs DDL inside the example's transaction, so the planted tables vanish with it.
  it "fails for a new table with a user_id column" do
    connection.create_table(:planted_user_notes) { |t| t.uuid :user_id }

    expect(Shared::DataRegistry.unregistered_tables(connection)).to eq([ "planted_user_notes" ])
  end

  # Identity creates and registers users later, so the example removes it from the list.
  it "fails for a users table left out, though it has no user_id column" do
    connection.create_table(:users, id: :uuid) unless connection.table_exists?(:users)
    registered = Shared::DataRegistry.registered_tables - [ "users" ]

    expect(Shared::DataRegistry.unregistered_tables(connection, registered:)).to eq([ "users" ])
  end

  it "ignores a table without user data" do
    connection.create_table(:planted_food_sources) { |t| t.string :name }

    expect(Shared::DataRegistry.unregistered_tables(connection)).to eq([])
  end
end

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

  describe "contexts" do
    it "exports every context that owns models" do
      missing = Shared::DataRegistry.contexts_without_exporter(Shared::DataRegistry.contexts_with_models)

      expect(missing).to eq([]), "Register an exporter for: #{missing.join(', ')}"
    end

    it "registry coverage fails if a context has no exporter" do
      Dir.mktmpdir do |root|
        FileUtils.mkdir_p(File.join(root, "planted_context/models"))
        File.write(File.join(root, "planted_context/models/note.rb"), "")
        FileUtils.mkdir_p(File.join(root, "empty_context"))

        contexts = Shared::DataRegistry.contexts_with_models(root)

        expect(contexts).to eq([ "planted_context" ])
        expect(Shared::DataRegistry.contexts_without_exporter(contexts)).to eq([ "planted_context" ])
      end
    end

    it "the export has one key per registered context" do
      expect(Shared::DataRegistry.export(user_id: SecureRandom.uuid).keys).to match_array(Shared::DataRegistry.contexts)
    end
  end
end

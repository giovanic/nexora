require "rails_helper"
require "support/outbox_helpers"

# AC-02-04: after the whole deletion flow, no table keeps the person's data.
# Every table not listed as without user data (DataRegistry, coverage spec), gets a row of
# the person and a unique marker in every text, string, JSON and array column
# the database lets it hold. Then every table of the database, whatever its
# shape, is searched for the marker and for the UUID.
RSpec.describe "account deletion scan", :real_consumers do
  include OutboxHelpers

  # Where a row points to its owner; every other table uses user_id.
  USER_COLUMN = { "users" => "id", "audit_events" => "user_ref" }.freeze
  # Rows the design keeps (4.4), so the scan does not plant content in them:
  # account_deletions is written by the flow itself, and audit_events is
  # checked against the closed list of its only writer, RecordAudit.
  NOT_SEEDED = %w[account_deletions audit_events].freeze
  # The event the deletion itself still needs (ruling R3).
  SEED_SCOPE = { "outbox_events" => "name <> 'user.deletion_requested'" }.freeze
  # Tables that keep the UUID, and the only columns they may have. A new
  # column in one of them fails here, so someone decides if it is erased.
  KEPT_COLUMNS = {
    "users" => %w[id email password_digest adult_confirmed_at deleted_at created_at updated_at],
    "consent_records" => %w[id user_id purpose text_version action source occurred_at],
    "audit_events" => %w[id user_ref action metadata ip_hmac occurred_at],
    "account_deletions" => %w[id user_id requested_at pending_contexts completed_at],
    "outbox_events" => %w[id name version user_id correlation_id payload occurred_at published_at attempts next_attempt_at dead_at]
  }.freeze

  let(:connection) { ActiveRecord::Base.connection }
  let(:marker) { "zzmark#{SecureRandom.hex(8)}" }
  let(:password) { "correct horse battery" }

  before { allow(Identity::EraseAccountJob).to receive(:perform_async) }

  def quote(value) = connection.quote(value)
  def table_name(table) = connection.quote_table_name(table)
  def column_name(column) = connection.quote_column_name(column)

  def user_tables
    (Shared::DataRegistry.user_data_tables(connection) | (Shared::DataRegistry.registered_tables & connection.tables)).sort
  end

  # A different value per row, so unique indexes do not refuse it.
  def marker_value
    "#{quote(marker)} || '-' || md5(random()::text)"
  end

  def marker_expression(column)
    return "ARRAY[#{marker_value}]::#{column.sql_type}[]" if column.array?

    case column.type
    when :string, :text then marker_value
    when :jsonb, :json then "jsonb_build_object(#{quote(marker)}, #{marker_value})::#{column.sql_type}"
    end
  end

  # For a table the flow left without a row of the person, such as a new one.
  def insert_row(table, user_id, owner)
    values = connection.columns(table).filter_map do |column|
      next [ column.name, quote(user_id) ] if column.name == owner
      next if column.null || column.default || column.default_function

      [ column.name, marker_expression(column) || filler(column) ]
    end
    connection.execute("INSERT INTO #{table_name(table)} (#{values.map { |name, _| column_name(name) }.join(', ')}) " \
                       "VALUES (#{values.map(&:last).join(', ')})")
  end

  def filler(column)
    { uuid: "gen_random_uuid()", datetime: "now()", date: "current_date", integer: "1", bigint: "1", boolean: "false",
      decimal: "0", float: "0" }.fetch(column.type) { raise "the scan cannot fill #{column.name} (#{column.sql_type})" }
  end

  # Returns the columns that took the marker. A column the database refuses
  # it for holds only closed-list values, so nothing personal fits there.
  def seed(table, user_id)
    owner = USER_COLUMN.fetch(table, "user_id")
    where = [ "#{column_name(owner)} = #{quote(user_id)}", SEED_SCOPE[table] ].compact.join(" AND ")
    insert_row(table, user_id, owner) unless connection.select_value("SELECT 1 FROM #{table_name(table)} WHERE #{where} LIMIT 1")

    connection.columns(table).filter_map do |column|
      expression = marker_expression(column) unless column.name == owner
      next unless expression

      connection.transaction(requires_new: true) do
        connection.execute("UPDATE #{table_name(table)} SET #{column_name(column.name)} = #{expression} WHERE #{where}")
      end
      column.name
    rescue ActiveRecord::StatementInvalid
      nil
    end
  end

  # Tables with rows whose text holds the value, from the whole row as text.
  def found(value)
    connection.tables.each_with_object({}) do |table, found|
      count = connection.select_value("SELECT count(*) FROM #{table_name(table)} AS r WHERE r::text LIKE #{quote("%#{value}%")}")
      found[table] = count if count.positive?
    end
  end

  # Every context with data gets some: two sessions, profile, sport, consent.
  # The marker goes in after the request, so the password still checks, and
  # before the erasure, which is what removes data.
  def request_deletion_with_data
    user_id = Identity::Api.register(email: "ana@example.test", password:, adult_confirmed: true, time_zone: "America/Sao_Paulo",
                                     client: "mobile", device_label: "Pixel 8", ip: "203.0.113.7").user_id
    run_publisher
    Identity::Api.grant_consent(user_id:, purpose: "health_data", version: 1, source: "mobile")
    UserProfile::Api.update_profile(user_id:, attrs: { display_name: "Ana", motivations: [ "track_progress" ] })
    UserProfile::Api.set_sport(user_id:, sport: "running", level: "beginner")
    Identity::Api.authenticate(email: "ana@example.test", password:, client: "web", device_label: nil, ip: nil)
    expect(Identity::Api.request_deletion(user_id:, password:, ip: nil)).to eq(:scheduled)

    seeded = (user_tables - NOT_SEEDED).to_h { |table| [ table, seed(table, user_id) ] }
    [ user_id, seeded ]
  end

  def erase(user_id)
    Identity::EraseAccountJob.new.perform(Identity::AccountDeletion.find_by!(user_id:).id)
  end

  it "scan seeds every table, including JSON columns, with a marker and finds none after erase" do
    user_id, seeded = request_deletion_with_data
    expect(seeded).to include("users" => include("email", "password_digest"), "outbox_events" => include("payload"),
                              "user_profiles" => include("display_name", "notification_preferences"), "sessions" => include("device_label"))
    expect(found(marker).keys).to include("users", "sessions", "user_profiles", "outbox_events")

    erase(user_id)

    expect(found(marker)).to eq({})
    expect(found(user_id).keys - KEPT_COLUMNS.keys).to eq([])
  end

  it "what stays keeps only the UUID, dates and closed-list values" do
    user_id, = request_deletion_with_data
    erase(user_id)

    KEPT_COLUMNS.each { |table, columns| expect(connection.columns(table).map(&:name)).to match_array(columns), table }
    expect(Shared::Outbox::Event.where(user_id:).pluck(:name, :payload)).to eq([ [ "user.deletion_requested", {} ] ])
    expect(Identity::AccountDeletion.where(user_id:).pluck(:pending_contexts)).to eq([ [] ])
    Identity::AuditEvent.where(user_ref: user_id).find_each do |audit|
      allowed = Identity::RecordAudit::METADATA.fetch(audit.action)
      audit.metadata.each { |field, value| expect(allowed.fetch(field)).to include(value) }
    end
    expect(Identity::ConsentRecord.where(user_id:).count).to eq(1)
  end

  # PostgreSQL runs DDL inside the example's transaction, so the planted table vanishes with it.
  it "fails for a new table without treatment" do
    connection.create_table(:planted_user_notes, id: :uuid) do |t|
      t.uuid :user_id, null: false
      t.text :note, null: false
      t.jsonb :details, null: false
    end
    user_id, seeded = request_deletion_with_data
    expect(seeded.fetch("planted_user_notes")).to contain_exactly("note", "details")

    erase(user_id)

    expect(found(marker).keys).to eq([ "planted_user_notes" ])
  end

  it "fails for a table registered with an eraser that leaves its rows" do
    connection.create_table(:planted_user_notes, id: :uuid) { |t| t.uuid :user_id }
    Shared::DataRegistry.register(context: "planted", tables: %w[planted_user_notes], exporter: ->(_id) { {} }, eraser: ->(_id) { nil })
    user_id, = request_deletion_with_data

    erase(user_id)

    expect(found(user_id).keys - KEPT_COLUMNS.keys).to eq([ "planted_user_notes" ])
  end
end

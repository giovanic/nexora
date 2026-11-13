module Shared
  # Each context with user data registers here, at boot, how to export and erase
  # it. Account export and deletion walk this list, so neither Identity nor this
  # module names another context (design of Phase 02, section 4.4).
  #
  # Registrations live in memory and are rebuilt on every code load, so contexts
  # register inside `Rails.application.config.to_prepare`.
  module DataRegistry
    Entry = Data.define(:context, :tables, :exporter, :eraser)

    # Rails' own bookkeeping, never user data.
    RAILS_INTERNAL_TABLES = %w[schema_migrations ar_internal_metadata].freeze
    # Every other table must be registered by a context, or be listed here with
    # the reason it holds no data about a person. A user_id column is not what
    # decides it (users has none, audit_events uses user_ref).
    TABLES_WITHOUT_USER_DATA = {
      "consumed_events" => "Only a consumer name and an event id; its rows go with outbox_events (ON DELETE CASCADE)."
    }.freeze

    @entries = {}

    class << self
      # exporter.call(user_id) returns a JSON-ready Hash; eraser.call(user_id)
      # removes that user's rows and must be safe to run again.
      def register(context:, tables:, exporter:, eraser:)
        context = context.to_s
        tables = Array(tables).map(&:to_s)
        raise ArgumentError, "#{context} must register at least one table" if tables.empty?
        raise ArgumentError, "#{context} needs an exporter and an eraser that respond to call" unless [ exporter, eraser ].all? { |handler| handler.respond_to?(:call) }

        claimed = tables & @entries.except(context).values.flat_map(&:tables)
        raise ArgumentError, "already registered by another context: #{claimed.join(', ')}" if claimed.any?

        @entries[context] = Entry.new(context:, tables: tables.freeze, exporter:, eraser:)
        nil
      end

      def export(user_id:)
        @entries.transform_values { |entry| entry.exporter.call(user_id) }
      end

      def erasers
        @entries.map { |context, entry| [ context, entry.eraser ] }
      end

      def contexts
        @entries.keys
      end

      # Contexts under app/domains that own models, so tables. Each one must
      # register an exporter; the coverage spec requires contexts_without_exporter
      # to be empty.
      def contexts_with_models(root = Rails.root.join("app/domains"))
        Dir.children(root.to_s).select { |name| Dir.glob(File.join(root.to_s, name, "models", "**", "*.rb")).any? }.sort
      end

      def contexts_without_exporter(contexts_to_check)
        contexts_to_check.map(&:to_s) - @entries.select { |_, entry| entry.exporter.respond_to?(:call) }.keys
      end

      def registered_tables
        @entries.values.flat_map(&:tables).uniq.sort
      end

      # Every table of the database that is not Rails-internal and not listed as
      # without user data. All of them must be registered.
      def user_data_tables(connection, without_user_data: TABLES_WITHOUT_USER_DATA)
        (connection.tables - RAILS_INTERNAL_TABLES - without_user_data.keys).sort
      end

      # Tables that no context registered and nobody listed as without user
      # data. The coverage spec requires it to be empty.
      def unregistered_tables(connection, registered: registered_tables, without_user_data: TABLES_WITHOUT_USER_DATA)
        (user_data_tables(connection, without_user_data:) - registered).sort
      end

      # Lets specs register handlers without leaking them into other examples.
      def preserving_registrations
        saved = @entries.dup
        yield
      ensure
        @entries = saved
      end
    end
  end
end

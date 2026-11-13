module Shared
  # Each context with user data registers here, at boot, how to export and erase
  # it. Account export and deletion walk this list, so neither Identity nor this
  # module names another context (design of Phase 02, section 4.4).
  #
  # Registrations live in memory and are rebuilt on every code load, so contexts
  # register inside `Rails.application.config.to_prepare`.
  module DataRegistry
    Entry = Data.define(:context, :tables, :exporter, :eraser)

    # Tables that hold user data even without a user_id column.
    ALWAYS_USER_DATA = %w[users].freeze

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

      # Tables with user data that no context registered. The coverage spec
      # requires it to be empty.
      def unregistered_tables(connection, registered: registered_tables)
        user_tables = connection.tables.select do |table|
          ALWAYS_USER_DATA.include?(table) || connection.column_exists?(table, :user_id)
        end
        (user_tables - registered).sort
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

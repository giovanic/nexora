require "base64"

module Goals
  # Completed days only, newest first, ties by goal id, ended goals included. Grouped by (goal, day) in the database,
  # one page at a time, by an opaque cursor over (local_date, goal_id). Days not completed are never listed.
  # Returns Api::HistoryPage, :not_found (another person's or malformed goal_id) or Api::Errors validation_failed.
  module History
    DEFAULT_LIMIT = 30
    MAX_LIMIT = 100
    DATE = /\A\d{4}-\d{2}-\d{2}\z/
    COLUMNS = %w[goal_check_ins.local_date goal_check_ins.goal_id goals.goal_type goals.status goals.rule_version].freeze

    def self.call(user_id:, goal_id:, cursor:, limit:)
      errors = []
      size = parse_limit(limit, errors)
      position = parse_cursor(cursor, errors)
      return Api::Errors.new(code: "validation_failed", details: errors) if errors.any?

      if goal_id
        goal = Goal.owned(user_id, goal_id)
        return :not_found unless goal
      end

      rows = page(user_id, goal&.id, position, size).to_a
      more = rows.size > size
      rows = rows.first(size)
      Api::HistoryPage.new(days: rows.filter_map { |row| day(row) }, next_cursor: (encode(rows.last) if more))
    end

    def self.page(user_id, goal_id, position, size)
      scope = GoalCheckIn.joins(:goal).where(user_id:)
      scope = scope.where(goal_id:) if goal_id
      scope = scope.where("(goal_check_ins.local_date, goal_check_ins.goal_id) < (?::date, ?::uuid)", *position) if position
      scope.group(*COLUMNS)
           .select(*COLUMNS, "string_agg(DISTINCT goal_check_ins.source, ',' ORDER BY goal_check_ins.source) AS sources")
           .order("goal_check_ins.local_date DESC", "goal_check_ins.goal_id DESC")
           .limit(size + 1)
    end

    # The grouped row stands for the day's check-ins: it answers local_date, which is all a rule reads.
    def self.day(row)
      return unless EvaluateDay.call(rule_version: row.rule_version, local_date: row.local_date, check_ins: [ row ])

      Api::HistoryDay.new(goal_id: row.goal_id, goal_type: row.goal_type, goal_status: row.status, local_date: row.local_date,
                          sources: row.sources.split(","))
    end

    def self.parse_limit(value, errors)
      return DEFAULT_LIMIT if value.nil?

      number = value.is_a?(Integer) ? value : (Integer(value, 10) if value.is_a?(String) && value.match?(/\A\d{1,9}\z/))
      return number if number&.between?(1, MAX_LIMIT)

      errors << { field: "limit", code: "out_of_range" }
      DEFAULT_LIMIT
    end

    # [local_date, goal_id] of the last row of the previous page.
    def self.parse_cursor(value, errors)
      return if value.nil?

      date, id = JSON.parse(Base64.urlsafe_decode64(value)) if value.is_a?(String) && value.length <= 200
      return [ Date.iso8601(date), id ] if date.is_a?(String) && date.match?(DATE) && id.is_a?(String) && id.match?(Goal::UUID)

      errors << { field: "cursor", code: "invalid" }
      nil
    rescue ArgumentError, JSON::ParserError, Date::Error
      errors << { field: "cursor", code: "invalid" }
      nil
    end

    def self.encode(row)
      Base64.urlsafe_encode64([ row.local_date.iso8601, row.goal_id ].to_json, padding: false)
    end
    private_class_method :page, :day, :parse_limit, :parse_cursor, :encode
  end
end

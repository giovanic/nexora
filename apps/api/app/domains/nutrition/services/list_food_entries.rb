require "base64"

module Nutrition
  # The person's history, newest day first, then the newest meal of the day, by cursor. 20 per page,
  # at most 50. A meal still waiting for its photo (pending) is not listed. No total and no sum: each
  # meal carries only its own ranges. Items are loaded in one query for the whole page.
  # Returns { entries:, next_cursor: } or Errors (validation_failed, naming the field).
  module ListFoodEntries
    DEFAULT_PER_PAGE = 20
    MAX_PER_PAGE = 50
    UUID = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/
    DATE = /\A\d{4}-\d{2}-\d{2}\z/

    def self.call(user_id:, local_date:, cursor:, per_page:)
      errors = []
      date = parse_date(local_date, errors)
      position = parse_cursor(cursor, errors)
      limit = parse_per_page(per_page, errors)
      return Api::Errors.new(code: "validation_failed", details: errors) if errors.any?

      rows = page(user_id, date, position, limit).to_a
      more = rows.size > limit
      rows = rows.first(limit)
      { entries: rows, next_cursor: (encode(rows.last) if more) }
    end

    def self.page(user_id, date, position, limit)
      scope = FoodEntry.where(user_id:).where.not(status: "pending")
      scope = scope.where(local_date: date) if date
      scope = scope.where("(local_date, meal_at, id) < (?::date, ?::timestamp, ?::uuid)", *position) if position
      scope.order(local_date: :desc, meal_at: :desc, id: :desc).limit(limit + 1).includes(:visible_items)
    end

    def self.parse_date(value, errors)
      return if value.nil?

      return Date.iso8601(value) if value.is_a?(String) && value.match?(DATE)

      errors << { field: "local_date", code: "invalid" }
      nil
    rescue Date::Error
      errors << { field: "local_date", code: "invalid" }
      nil
    end

    def self.parse_per_page(value, errors)
      return DEFAULT_PER_PAGE if value.nil?

      number = Integer(value, 10) if value.is_a?(Integer) || (value.is_a?(String) && value.match?(/\A\d{1,9}\z/))
      return [ number, MAX_PER_PAGE ].min if number&.positive?

      errors << { field: "per_page", code: "invalid" }
      DEFAULT_PER_PAGE
    end

    # [local_date, meal_at, id] of the last meal of the previous page.
    def self.parse_cursor(value, errors)
      return if value.nil?

      date, time, id = JSON.parse(Base64.urlsafe_decode64(value)) if value.is_a?(String) && value.length <= 200
      if date.is_a?(String) && date.match?(DATE) && time.is_a?(String) && id.is_a?(String) && id.match?(UUID)
        return [ Date.iso8601(date), Time.iso8601(time), id ]
      end

      errors << { field: "cursor", code: "invalid" }
      nil
    rescue ArgumentError, JSON::ParserError, Date::Error
      errors << { field: "cursor", code: "invalid" }
      nil
    end

    def self.encode(entry)
      Base64.urlsafe_encode64([ entry.local_date.iso8601, entry.meal_at.utc.iso8601(6), entry.id ].to_json, padding: false)
    end
    private_class_method :page, :parse_date, :parse_per_page, :parse_cursor, :encode
  end
end

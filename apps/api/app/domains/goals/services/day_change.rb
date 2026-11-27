module Goals
  # Shared steps of the manual check-in and uncheck: lock the person's goal, refuse a goal that is not active and a
  # date outside yesterday and today (or before the goal started), then record the day. The block does the write.
  # DayInfo, :not_found (also another person's goal or a malformed id) or Errors.
  module DayChange
    def self.call(user_id:, goal_id:, local_date:, &write)
      date = local_date.is_a?(Date) ? local_date : LocalDay.parse(local_date)
      return refusal("invalid") unless date

      yesterday, today = LocalDay.window(user_id:)
      Goal.transaction do
        goal = Goal.owned(user_id, goal_id, lock: true)
        next :not_found unless goal
        next Api::Errors.new(code: "goal_not_active", details: []) unless goal.status == "active"
        next refusal("outside_window") unless date.between?(yesterday, today) && date >= goal.starts_on

        RecordDay.call(goal:, local_date: date, &write)
      end
    end

    def self.refusal(code) = Api::Errors.new(code: "validation_failed", details: [ { field: "local_date", code: } ])
    private_class_method :refusal
  end
end

module Goals
  # Changes the check-ins of one goal day and publishes the completion transition. Locks the goal, evaluates the day,
  # runs the block (which writes or deletes check-ins of that day), evaluates again and publishes goal.completed or
  # goal.uncompleted when the day changed state. Runs inside the caller's transaction, so the lock lasts until it ends.
  # Returns Api::DayInfo. Shared by the manual check-in and the meal consumers.
  module RecordDay
    def self.call(goal:, local_date:)
      raise ArgumentError, "RecordDay needs a transaction" unless Goal.connection.transaction_open?

      goal.lock!
      before = evaluate(goal, local_date, rows(goal, local_date))
      yield goal, local_date
      check_ins = rows(goal, local_date)
      after = evaluate(goal, local_date, check_ins)
      publish(goal, local_date, before:, after:)
      Api::DayInfo.new(goal_id: goal.id, local_date:, done: after, sources: check_ins.map(&:source).uniq.sort)
    end

    def self.rows(goal, local_date) = goal.check_ins.where(local_date:).to_a

    def self.evaluate(goal, local_date, check_ins) = EvaluateDay.call(rule_version: goal.rule_version, local_date:, check_ins:)

    def self.publish(goal, local_date, before:, after:)
      return if before == after

      payload = { goal_id: goal.id, period_key: local_date.iso8601 }
      if after
        payload = payload.merge(goal_type: goal.goal_type, local_date: local_date.iso8601, rule_version: goal.rule_version)
        Shared::Outbox.publish!(name: "goal.completed", user_id: goal.user_id, payload:)
      else
        Shared::Outbox.publish!(name: "goal.uncompleted", user_id: goal.user_id, payload:)
      end
    end
    private_class_method :rows, :evaluate, :publish
  end
end

module Goals
  # Pauses, resumes or ends a goal. The goal is locked for the change. The same status changes nothing; an ended goal
  # is final. Nothing goes to the outbox. GoalInfo, :not_found (also another person's goal) or Errors.
  module ChangeStatus
    def self.call(user_id:, goal_id:, status:)
      return Api::Errors.new(code: "validation_failed", details: [ { field: "status", code: "inclusion" } ]) unless Goal::STATUSES.include?(status)

      yesterday, today = LocalDay.window(user_id:)
      result = Goal.transaction do
        goal = Goal.owned(user_id, goal_id, lock: true)
        next :not_found unless goal
        next Api::Errors.new(code: "goal_not_active", details: []) if goal.status == "ended"

        apply(goal, status, today) unless goal.status == status
        goal
      end
      result.is_a?(Goal) ? GoalView.call(result, today:, yesterday:) : result
    end

    def self.apply(goal, status, today)
      case status
      when "paused" then goal.update!(status:, paused_at: Time.current)
      when "active" then goal.update!(status:, paused_at: nil)
      when "ended" then goal.update!(status:, ends_on: today)
      end
    end
  end
end

module Goals
  # A goal as clients show it: whether today and yesterday are complete under the goal's own rule version.
  module GoalView
    def self.call(goal, today:, yesterday:, created: false)
      check_ins = goal.check_ins.where(local_date: [ yesterday, today ]).to_a
      done = ->(date) { EvaluateDay.call(rule_version: goal.rule_version, local_date: date, check_ins:) }
      Api::GoalInfo.new(id: goal.id, goal_type: goal.goal_type, status: goal.status, starts_on: goal.starts_on, ends_on: goal.ends_on,
                        done_today: done.call(today), done_yesterday: done.call(yesterday), created:)
    end
  end
end

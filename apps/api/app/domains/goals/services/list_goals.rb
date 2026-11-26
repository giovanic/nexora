module Goals
  # The person's live goals (active first, then paused, oldest first) with today and yesterday under each goal's rule.
  module ListGoals
    def self.call(user_id:)
      yesterday, today = LocalDay.window(user_id:)
      goals = Goal.where(user_id:, status: Goal::LIVE).order(:status, :created_at, :id)
      Api::GoalList.new(today_local_date: today, yesterday_local_date: yesterday,
                        goals: goals.map { |goal| GoalView.call(goal, today:, yesterday:) })
    end
  end
end

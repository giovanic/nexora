module Goals
  # One goal of the person, an ended one included (the list leaves it out). GoalInfo, or :not_found (also another
  # person's goal or a malformed id).
  module ReadGoal
    def self.call(user_id:, goal_id:)
      goal = Goal.owned(user_id, goal_id)
      return :not_found unless goal

      yesterday, today = LocalDay.window(user_id:)
      GoalView.call(goal, today:, yesterday:)
    end
  end
end

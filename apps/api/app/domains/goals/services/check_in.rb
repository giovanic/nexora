module Goals
  # Marks a day done by hand. One manual check-in per goal and day: a repeat (or a request racing with another)
  # changes nothing and publishes nothing. DayInfo, :not_found or Errors.
  module CheckIn
    def self.call(user_id:, goal_id:, local_date:)
      DayChange.call(user_id:, goal_id:, local_date:) do |goal, date|
        GoalCheckIn.insert_all([ { goal_id: goal.id, user_id: goal.user_id, local_date: date, source: "manual", checked_at: Time.current } ],
                               unique_by: :index_goal_check_ins_one_manual_per_day)
      end
    end
  end
end

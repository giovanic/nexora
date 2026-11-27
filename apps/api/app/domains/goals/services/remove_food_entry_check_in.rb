module Goals
  # Consumer of food_entry.deleted. Removes the check-in of that meal from any goal of the person and evaluates the
  # day again, so the day goes back to not done when the meal was the only reason. Manual check-ins and other meals
  # stay. A goal or account already gone, or a meal that never counted, is a quiet no-op.
  #
  # Order of events: food_entry.confirmed and food_entry.deleted of one meal can arrive in any order. This consumer
  # first locks all the person's log_meals goals (by id, so two of them never lock in opposite orders), then leaves a
  # marker for the meal, then removes the check-ins. CheckInFromFoodEntry locks the same goals row. If the confirmation
  # commits first, this one waits for the lock and sees the check-in. If this one commits first, the confirmation sees
  # the marker and records nothing. A person without a log_meals goal has no check-in to protect.
  module RemoveFoodEntryCheckIn
    def self.call(event)
      meal_id = event.payload["food_entry_id"]
      return unless meal_id.to_s.match?(Goal::UUID)

      Goal.transaction do
        Goal.lock.where(user_id: event.user_id, goal_type: "log_meals").order(:id).load
        RemovedFoodEntry.insert_all([ { user_id: event.user_id, food_entry_id: meal_id, created_at: Time.current } ],
                                    unique_by: :index_goal_removed_food_entries_on_user_and_meal)

        GoalCheckIn.where(user_id: event.user_id, source: "food_entry", source_ref: meal_id).pluck(:goal_id, :local_date).each do |goal_id, date|
          goal = Goal.lock.find_by(id: goal_id)
          next unless goal

          RecordDay.call(goal:, local_date: date) { |locked, day| locked.check_ins.where(local_date: day, source: "food_entry", source_ref: meal_id).delete_all }
        end
      end
    end
  end
end

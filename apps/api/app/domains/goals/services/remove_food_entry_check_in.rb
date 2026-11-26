module Goals
  # Consumer of food_entry.deleted. Removes the check-in of that meal from any goal of the person and evaluates the
  # day again, so the day goes back to not done when the meal was the only reason. Manual check-ins and other meals
  # stay. A goal or account already gone, or a meal that never counted, is a quiet no-op.
  module RemoveFoodEntryCheckIn
    def self.call(event)
      meal_id = event.payload["food_entry_id"]
      return unless meal_id.to_s.match?(Goal::UUID)

      Goal.transaction do
        GoalCheckIn.where(user_id: event.user_id, source: "food_entry", source_ref: meal_id).pluck(:goal_id, :local_date).each do |goal_id, date|
          goal = Goal.lock.find_by(id: goal_id)
          next unless goal

          RecordDay.call(goal:, local_date: date) { |locked, day| locked.check_ins.where(local_date: day, source: "food_entry", source_ref: meal_id).delete_all }
        end
      end
    end
  end
end

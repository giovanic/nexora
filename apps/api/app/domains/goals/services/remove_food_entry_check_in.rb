module Goals
  # Consumer of food_entry.deleted. Removes the check-in of that meal from any goal of the person and evaluates the
  # day again, so the day goes back to not done when the meal was the only reason. Manual check-ins and other meals
  # stay. A goal or account already gone, or a meal that never counted, is a quiet no-op.
  #
  # Order of events: food_entry.confirmed and food_entry.deleted of one meal can arrive in any order. Both consumers
  # first take the same per-person advisory lock (MealEventLock), so they never overlap. This one then leaves a
  # marker for the meal and removes its check-ins, each goal under its own lock, which also serializes with manual
  # check-ins; a goal deleted meanwhile is skipped. If the confirmation commits first, this one waits and sees the check-in. If this one commits
  # first, the confirmation sees the marker and records nothing. That holds even if the person creates a log_meals goal
  # meanwhile. A person with no users row (account gone) is a quiet no-op: the marker is not written.
  module RemoveFoodEntryCheckIn
    def self.call(event)
      meal_id = event.payload["food_entry_id"]
      return unless meal_id.to_s.match?(Goal::UUID)

      Goal.transaction do
        MealEventLock.acquire(event.user_id)
        next unless mark_removed(event.user_id, meal_id)

        GoalCheckIn.where(user_id: event.user_id, source: "food_entry", source_ref: meal_id).pluck(:goal_id, :local_date).each do |goal_id, date|
          goal = Goal.lock.find_by(id: goal_id)
          next unless goal

          RecordDay.call(goal:, local_date: date) { |locked, day| locked.check_ins.where(local_date: day, source: "food_entry", source_ref: meal_id).delete_all }
        end
      end
    end

    # False when the person's users row does not exist (foreign key), inside a savepoint so the transaction survives.
    def self.mark_removed(user_id, meal_id)
      Goal.transaction(requires_new: true) do
        RemovedFoodEntry.insert_all([ { user_id:, food_entry_id: meal_id, created_at: Time.current } ],
                                    unique_by: :index_goal_removed_food_entries_on_user_and_meal)
      end
      true
    rescue ActiveRecord::InvalidForeignKey
      false
    end
    private_class_method :mark_removed
  end
end

module Goals
  # Consumer of food_entry.confirmed. A confirmed meal completes the day of the person's active log_meals goal. It
  # uses the event's fields only (never Nutrition's tables) and does nothing when there is no active goal, the date
  # is invalid or before the goal started, or the goal vanished meanwhile. The meal's own date counts, so the
  # yesterday-and-today window of the manual check-in does not apply. A repeat changes nothing (unique index on the source).
  #
  # Order of events: it takes the per-person advisory lock (MealEventLock) first, the same one RemoveFoodEntryCheckIn
  # takes, then the goal lock, then looks for the deletion marker of the meal. So either this one commits first and the
  # deletion sees its check-in, or the deletion commits first and this one sees the marker and records nothing, with no
  # event. A log_meals goal created meanwhile does not change that.
  module CheckInFromFoodEntry
    def self.call(event)
      meal_id = event.payload["food_entry_id"]
      date = LocalDay.parse(event.payload["local_date"])
      return unless date && meal_id.to_s.match?(Goal::UUID)

      Goal.transaction do
        MealEventLock.acquire(event.user_id)
        goal = Goal.lock.find_by(user_id: event.user_id, goal_type: "log_meals", status: "active")
        next unless goal && date >= goal.starts_on
        next if RemovedFoodEntry.exists?(user_id: event.user_id, food_entry_id: meal_id)

        RecordDay.call(goal:, local_date: date) do |locked, day|
          GoalCheckIn.insert_all([ { goal_id: locked.id, user_id: locked.user_id, local_date: day, source: "food_entry", source_ref: meal_id,
                                     checked_at: Time.current } ], unique_by: :index_goal_check_ins_one_per_source_ref)
        end
      end
    end
  end
end

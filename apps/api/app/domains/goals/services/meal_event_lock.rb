module Goals
  # Transaction-scoped advisory lock keyed by the person, taken first by both meal consumers
  # (CheckInFromFoodEntry and RemoveFoodEntryCheckIn). It serializes them even when the person has no log_meals goal
  # yet, or creates one meanwhile, which a lock on goals rows cannot do. Released at commit or rollback.
  module MealEventLock
    def self.acquire(user_id)
      raise ArgumentError, "MealEventLock needs a user_id" if user_id.blank?
      raise ArgumentError, "MealEventLock needs a transaction" unless Goal.connection.transaction_open?

      key = Goal.sanitize_sql_array([ "SELECT pg_advisory_xact_lock(hashtextextended(?, 0))", "goals.meal_events:#{user_id}" ])
      Goal.connection.execute(key)
    end
  end
end

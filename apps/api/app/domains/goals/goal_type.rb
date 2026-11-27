module Goals
  # The closed list of goal types (design 4.1). The database repeats it in a CHECK.
  module GoalType
    ALL = %w[log_meals include_fruits_vegetables drink_water sleep_routine planned_workout].freeze

    def self.allowed?(code) = ALL.include?(code)
  end
end

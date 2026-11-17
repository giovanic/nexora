module Nutrition
  # Runs a change on the person's meal with the meal locked, so two changes (or a change and the
  # analysis arriving) do not interleave. Only an analyzed or confirmed meal takes changes: a meal
  # still being analyzed has nothing to correct yet. Yields the locked meal; its block returns the result.
  # :not_found also for another person's meal, or Errors (entry_not_editable).
  module EditableEntry
    EDITABLE = %w[analyzed confirmed].freeze

    def self.with(user_id:, food_entry_id:)
      FoodEntry.transaction do
        entry = FoodEntry.lock.find_by(user_id:, id: food_entry_id)
        next :not_found unless entry
        next Api::Errors.new(code: "entry_not_editable") unless EDITABLE.include?(entry.status)

        yield entry
      end
    end
  end
end

module Nutrition
  # Stores the meal's ranges again after its visible items changed. The arithmetic is Calculator's, the
  # same as when the analysis arrived, and the rounding stays in EntryView.
  module RecalculateEntry
    def self.call(entry)
      entry.visible_items.reset
      meal = Calculator.meal(entry.visible_items.to_a)
      entry.update!(estimate_partial: meal.fetch(:estimate_partial), **meal.slice(:calories_min, :calories_likely, :calories_max))
      entry
    end
  end
end

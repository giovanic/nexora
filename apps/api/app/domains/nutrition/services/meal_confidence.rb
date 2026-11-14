module Nutrition
  # Confidence of a meal, from the initial criteria of AI_ARCHITECTURE (to be calibrated with the dataset),
  # combining the model's confidence per item with the kind of match:
  #   low:    an item below 0.5 or an unknown item (and a meal with no item);
  #   medium: an item from 0.5 to below 0.8, a possible hidden ingredient, or a match by composition;
  #   high:   every item at least 0.8 with a direct match (an ingredient).
  # An item the person set has no model confidence and counts as certain.
  module MealConfidence
    LOW_BELOW = BigDecimal("0.5")
    HIGH_FROM = BigDecimal("0.8")

    def self.call(items)
      return "low" if items.empty? || items.any? { |item| item.unknown? || confidence(item) < LOW_BELOW }
      return "medium" if items.any? { |item| confidence(item) < HIGH_FROM || item.hidden_ingredients_possible || composition?(item) }

      "high"
    end

    def self.confidence(item)
      item.confidence || (item.origin == "user" ? BigDecimal("1") : BigDecimal("0"))
    end

    # Compositions of the project are the only matches that are not a single ingredient.
    def self.composition?(item)
      item.nutrition_source_ref&.fetch("source", nil) == "project" || item.nutrition_source_ref&.fetch(:source, nil) == "project"
    end
    private_class_method :confidence, :composition?
  end
end

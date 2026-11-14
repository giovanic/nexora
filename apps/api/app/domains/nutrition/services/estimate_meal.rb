module Nutrition
  # The numbers of a meal from portions and catalog ids, without writing anything: the same arithmetic
  # (Calculator) and the same rounding (EntryView) as a stored meal. An item with no catalog id, or with an
  # id the catalog does not know, is unknown: no numbers, and the estimate is partial.
  module EstimateMeal
    # items: [{ catalog_item_id:, grams_min:, grams_likely:, grams_max: }]
    def self.call(items:)
      built = items.map { |item| build(item) }
      meal = Calculator.meal(built)
      Api::EstimateInfo.new(ranges: EntryView.ranges(meal), estimate_partial: meal.fetch(:estimate_partial), unknown_items_count: meal.fetch(:unknown_count))
    end

    def self.build(item)
      grams = item.slice(:grams_min, :grams_likely, :grams_max)
      known = item[:catalog_item_id] && ItemBuilder.known(item[:catalog_item_id], **grams)
      FoodItem.new(known || ItemBuilder.unknown("item").merge(ItemBuilder.portion(**grams)))
    end
    private_class_method :build
  end
end

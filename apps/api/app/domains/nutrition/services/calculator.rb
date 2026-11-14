require "bigdecimal"

module Nutrition
  # The arithmetic of a meal, in BigDecimal from end to end. Nothing is rounded here: rounding is
  # for the response (EntryView). The only source of nutrients is the catalog's per-100 g values.
  module Calculator
    BOUNDS = %w[min likely max].freeze
    # catalog key => column prefix
    QUANTITIES = { energy_kcal: "calories", protein_g: "protein_g", carbs_g: "carbs_g", fat_g: "fat_g" }.freeze

    # per_100g: { energy_kcal:, protein_g:, carbs_g:, fat_g: }. Returns calories_min, calories_likely,
    # calories_max, protein_g_*, carbs_g_* and fat_g_*, each per_100g x grams / 100.
    def self.item(per_100g:, grams_min:, grams_likely:, grams_max:)
      grams = { "min" => decimal(grams_min), "likely" => decimal(grams_likely), "max" => decimal(grams_max) }
      QUANTITIES.each_with_object({}) do |(key, column), result|
        per = decimal(per_100g.fetch(key))
        BOUNDS.each { |bound| result[:"#{column}_#{bound}"] = per * grams.fetch(bound) / 100 }
      end
    end

    # items: anything with the readers of an item (FoodItem). Sums each quantity over the known items only
    # (those with a catalog_item_id). Quantities are nil when no item is known. unknown_count counts the
    # items the catalog did not match, and estimate_partial is true when there is any.
    def self.meal(items)
      known, unknown = items.partition { |item| item.catalog_item_id && !item.calories_likely.nil? }
      totals = QUANTITIES.values.product(BOUNDS).to_h do |column, bound|
        name = :"#{column}_#{bound}"
        [ name, known.empty? ? nil : known.sum(BigDecimal("0")) { |item| item.public_send(name) } ]
      end
      totals.merge(estimate_partial: unknown.any?, unknown_count: unknown.size)
    end

    def self.decimal(value) = value.is_a?(BigDecimal) ? value : BigDecimal(value.to_s)
    private_class_method :decimal
  end
end

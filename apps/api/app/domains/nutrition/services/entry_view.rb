module Nutrition
  # The meal as the clients show it, built from the stored items. This is the only place numbers are
  # rounded: calories to the ten, macros to the gram, always as min, likely and max. The response
  # carries no total of the day, no remaining, no goal and no judgement, and the clients compute nothing.
  module EntryView
    MACROS = %w[protein_g carbs_g fat_g].freeze
    BOUNDS = %w[min likely max].freeze

    def self.call(entry, photo_url: nil)
      items = entry.items.order(:created_at, :id).to_a
      meal = Calculator.meal(items)
      {
        id: entry.id, status: entry.status, result_code: entry.result_code, source: entry.source, meal_at: entry.meal_at.iso8601,
        local_date: entry.local_date.iso8601, estimate_partial: meal.fetch(:estimate_partial), unknown_items_count: meal.fetch(:unknown_count),
        confidence: (MealConfidence.call(items) if items.any?), photo_url:
      }.merge(ranges(meal)).merge(items: items.map { |item| item_view(item) })
    end

    def self.item_view(item)
      {
        id: item.id, name: item.display_name, origin: item.origin, unknown: item.unknown?, household_measure: item.household_measure,
        source: item.nutrition_source_ref&.fetch("source", nil), own_composition: item.nutrition_source_ref&.fetch("source", nil) == "project",
        quantity_grams_min: grams(item.quantity_grams_min), quantity_grams_likely: grams(item.quantity_grams_likely),
        quantity_grams_max: grams(item.quantity_grams_max)
      }.merge(ranges(item))
    end

    # source answers the 12 quantity readers (a FoodItem) or the meal hash of Calculator.meal.
    def self.ranges(source)
      read = ->(name) { source.is_a?(Hash) ? source[name] : source.public_send(name) }
      result = BOUNDS.to_h { |bound| [ :"calories_#{bound}", tens(read.call(:"calories_#{bound}")) ] }
      MACROS.each { |macro| BOUNDS.each { |bound| result[:"#{macro}_#{bound}"] = unit(read.call(:"#{macro}_#{bound}")) } }
      result
    end

    def self.tens(value) = value && (value / 10).round(0, BigDecimal::ROUND_HALF_UP).to_i * 10
    def self.unit(value) = value&.round(0, BigDecimal::ROUND_HALF_UP)&.to_i
    def self.grams(value) = value.frac.zero? ? value.to_i : value.to_f
    private_class_method :item_view, :ranges, :tens, :unit, :grams
  end
end

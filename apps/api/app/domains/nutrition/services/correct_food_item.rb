module Nutrition
  # Corrects the portion or the food of an item. The original stays in the database, hidden as
  # corrected, and a new item the person made (origin user, corrected_from_item_id) takes its place, in
  # the same position. A new portion keeps the proportion of the original between its minimum, likely
  # and maximum; a new food takes its name and numbers from the catalog. Then the meal is recalculated.
  # changes: a Hash with grams_likely and/or catalog_item_id, as sent. The meal, :not_found (also for
  # another person's meal or item, or an item already hidden) or Errors, which leave everything as it was.
  module CorrectFoodItem
    GRAMS = ItemInput::GRAMS
    MIN_GRAMS = BigDecimal("0.01")

    def self.call(user_id:, food_entry_id:, item_id:, changes:)
      EditableEntry.with(user_id:, food_entry_id:) do |entry|
        original = entry.visible_items.find_by(id: item_id)
        next :not_found unless original

        errors = validate(changes)
        next Api::Errors.new(code: "validation_failed", details: errors) if errors.any?

        replacement = replacement_for(original, changes)
        next Api::Errors.new(code: "validation_failed", details: [ { field: "catalog_item_id", code: "not_found" } ]) unless replacement

        original.update!(hidden_at: Time.current, hidden_reason: "corrected")
        FoodItem.create!(replacement.merge(food_entry: entry, origin: "user", confidence: nil, hidden_ingredients_possible: false,
                                           corrected_from_item_id: original.id, created_at: original.created_at))
        RecalculateEntry.call(entry)
      end
    end

    # Field errors for the changes: at least one of the two, grams from 1 to 2000, a catalog id as a string.
    def self.validate(changes)
      return [ { field: "grams_likely", code: "required" } ] unless changes.key?(:grams_likely) || changes.key?(:catalog_item_id)

      errors = []
      if changes.key?(:grams_likely)
        errors << { field: "grams_likely", code: grams_code(changes[:grams_likely]) } if grams_code(changes[:grams_likely])
      end
      errors << { field: "catalog_item_id", code: "invalid" } if changes.key?(:catalog_item_id) && !changes[:catalog_item_id].is_a?(String)
      errors
    end

    def self.grams_code(value)
      return "invalid" unless value.is_a?(Numeric) && (!value.is_a?(Float) || value.finite?)

      "out_of_range" unless GRAMS.cover?(BigDecimal(value.to_s))
    end

    # The attributes of the new item, or nil when the catalog does not know the id sent.
    def self.replacement_for(original, changes)
      portion = new_portion(original, changes[:grams_likely])
      same_grams = portion[:grams_likely] == original.quantity_grams_likely
      base = food_attributes(original, changes[:catalog_item_id], portion)
      base && base.merge(ItemBuilder.portion(**portion), household_measure: (original.household_measure if same_grams && changes[:catalog_item_id].nil?))
    end

    # The portion for a new likely weight, keeping the original proportions.
    def self.new_portion(original, likely)
      return { grams_min: original.quantity_grams_min, grams_likely: original.quantity_grams_likely, grams_max: original.quantity_grams_max } if likely.nil?

      likely = BigDecimal(likely.to_s).round(2)
      reference = original.quantity_grams_likely
      min = [ (likely * original.quantity_grams_min / reference).round(2), MIN_GRAMS ].max
      { grams_min: [ min, likely ].min, grams_likely: likely, grams_max: [ (likely * original.quantity_grams_max / reference).round(2), likely ].max }
    end

    # Name, source and numbers: from the catalog food chosen, else from the item's own food at the new
    # portion, else (a free-text item) a name and no numbers.
    def self.food_attributes(original, catalog_item_id, portion)
      return ItemBuilder.known(catalog_item_id, **portion) if catalog_item_id
      return ItemBuilder.unknown(original.display_name) if original.unknown?

      ItemBuilder.known(original.catalog_item_id, **portion) || ItemBuilder.unknown(original.display_name)
    end
    private_class_method :validate, :grams_code, :replacement_for, :new_portion, :food_attributes
  end
end

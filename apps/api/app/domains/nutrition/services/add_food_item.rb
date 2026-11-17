module Nutrition
  # Adds an item the person made to an analyzed or confirmed meal, then recalculates it. A food the
  # catalog does not know (free text) is an unknown item: a name and a portion, no numbers, and the
  # estimate becomes partial. Adding to a meal with no food clears its result_code.
  # raw: a Hash with catalog_item_id or free_text_name, and grams_*. The meal, :not_found or Errors
  # (entry_not_editable, validation_failed), which leave everything as it was.
  module AddFoodItem
    def self.call(user_id:, food_entry_id:, raw:)
      EditableEntry.with(user_id:, food_entry_id:) do |entry|
        input, errors = ItemInput.parse(raw)
        next Api::Errors.new(code: "validation_failed", details: errors) unless input

        attributes = ItemBuilder.from_input(input)
        next Api::Errors.new(code: "validation_failed", details: [ { field: "catalog_item_id", code: "not_found" } ]) unless attributes

        FoodItem.create!(attributes.merge(food_entry: entry))
        entry.update!(result_code: nil)
        RecalculateEntry.call(entry)
      end
    end
  end
end

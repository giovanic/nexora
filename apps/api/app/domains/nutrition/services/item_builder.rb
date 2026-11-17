module Nutrition
  # The stored columns of an item, from its portion and what the catalog knows. The only place that turns
  # a catalog food and grams into an item's name, source reference and numbers.
  module ItemBuilder
    # Name, source reference and nutrient ranges of a catalog food at these grams. nil for an unknown id.
    def self.known(catalog_item_id, grams_min:, grams_likely:, grams_max:)
      nutrients = FoodCatalog::Api.nutrients_for(catalog_item_id:)
      catalog_item = FoodCatalog::Api.item(catalog_item_id:)
      return unless nutrients && catalog_item

      with_catalog(nutrients, catalog_item, grams_min:, grams_likely:, grams_max:)
    end

    def self.with_catalog(nutrients, catalog_item, grams_min:, grams_likely:, grams_max:)
      Calculator.item(per_100g: nutrients.per_100g, grams_min:, grams_likely:, grams_max:).merge(
        catalog_item_id: catalog_item.id, display_name: catalog_item.name_pt,
        nutrition_source_ref: { source: nutrients.source, version: nutrients.source_version, id: nutrients.source_item_id }
      )
    end

    # An item the catalog does not know: a name and a portion, no numbers.
    def self.unknown(name) = { display_name: name, catalog_item_id: nil, nutrition_source_ref: nil }

    def self.portion(grams_min:, grams_likely:, grams_max:)
      { quantity_grams_min: grams_min, quantity_grams_likely: grams_likely, quantity_grams_max: grams_max }
    end

    # Attributes of an item the person made, from a parsed ItemInput, or nil when its catalog id is unknown.
    def self.from_input(input)
      grams = { grams_min: input.grams_min, grams_likely: input.grams_likely, grams_max: input.grams_max }
      base = input.catalog_item_id ? known(input.catalog_item_id, **grams) : unknown(input.free_text_name)
      base && base.merge(portion(**grams), origin: "user", confidence: nil, hidden_ingredients_possible: false)
    end
  end
end

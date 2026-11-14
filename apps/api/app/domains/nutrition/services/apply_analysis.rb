module Nutrition
  # Consumer nutrition.apply_analysis of food_analysis.completed (v1). It turns the outcome of an
  # analysis into the state of the meal. It is safe to deliver again, and to deliver late:
  #  - the meal is locked, and only a pending, processing or failed meal takes an outcome, so a second
  #    delivery finds it analyzed and does nothing, and a confirmed meal is never overwritten;
  #  - no food_entry_id (photo not linked yet), a meal that is gone or another person's: nothing to do;
  #  - cancelled (analysis_id may be nil) deletes the meal, if it was not analyzed or confirmed.
  # Item names, grams and numbers never reach a log or an error.
  module ApplyAnalysis
    OPEN = %w[pending processing failed].freeze
    NO_RESULT = %w[no_food unreadable].freeze

    def self.call(event)
      payload = event.payload
      return unless payload["food_entry_id"]

      FoodEntry.transaction do
        entry = FoodEntry.lock.find_by(id: payload["food_entry_id"], user_id: event.user_id)
        next unless entry && OPEN.include?(entry.status)

        case payload["outcome"]
        when "cancelled" then entry.destroy!
        when "failed" then entry.update!(status: "failed")
        when *NO_RESULT then entry.update!(status: "analyzed", result_code: payload["outcome"], estimate_partial: false, **no_numbers)
        when "analyzed" then analyzed(entry, payload["analysis_id"])
        end
      end
    end

    def self.analyzed(entry, analysis_id)
      analysis = FoodAi::Api.analysis(analysis_id:)
      return if analysis == :not_found || analysis.status != "succeeded"

      items = analysis.items.map { |info| build_item(entry, info) }
      items.each(&:save!)
      meal = Calculator.meal(items)
      entry.update!(status: "analyzed", result_code: nil, estimate_partial: meal.fetch(:estimate_partial),
                    **meal.slice(:calories_min, :calories_likely, :calories_max))
    end

    # Matched in the catalog: its name and numbers, with the source reference. Not matched: the model's
    # plain-text name, no nutrients. The model is never asked for, and never gives, a nutrient.
    def self.build_item(entry, info)
      attributes = { food_entry: entry, display_name: info.name, quantity_grams_min: info.grams_min, quantity_grams_likely: info.grams_likely,
                     quantity_grams_max: info.grams_max, household_measure: info.household_measure, confidence: info.confidence,
                     hidden_ingredients_possible: info.hidden_ingredients_possible == true, origin: "ai" }
      matched = match(info)
      if matched
        nutrients, catalog_item = matched
        attributes.merge!(Calculator.item(per_100g: nutrients.per_100g, grams_min: info.grams_min, grams_likely: info.grams_likely, grams_max: info.grams_max))
        attributes.merge!(catalog_item_id: catalog_item.id, display_name: catalog_item.name_pt,
                          nutrition_source_ref: { source: nutrients.source, version: nutrients.source_version, id: nutrients.source_item_id })
      end
      FoodItem.new(attributes)
    end

    def self.match(info)
      found = FoodCatalog::Api.match(name: info.name)
      return unless found

      nutrients = FoodCatalog::Api.nutrients_for(catalog_item_id: found.catalog_item_id)
      catalog_item = FoodCatalog::Api.item(catalog_item_id: found.catalog_item_id)
      [ nutrients, catalog_item ] if nutrients && catalog_item
    end

    def self.no_numbers = { calories_min: nil, calories_likely: nil, calories_max: nil }
    private_class_method :analyzed, :build_item, :match, :no_numbers
  end
end

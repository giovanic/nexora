module Nutrition
  # A meal the person registers by hand: no photo, no analysis and no use of the photo quota. It is born
  # confirmed, source manual, with 1 to 30 items the person made. The same client_request_id gives back
  # the same meal. Returns [meal, created] or Errors (validation_failed).
  module CreateManualEntry
    MAX_ITEMS = 30
    REQUEST_ID_MAX = 100

    def self.call(user_id:, client_request_id:, meal_at:, items:)
      errors = []
      errors << { field: "client_request_id", code: "invalid" } unless client_request_id.is_a?(String) && (1..REQUEST_ID_MAX).cover?(client_request_id.length)
      time = MealTime.parse(meal_at)
      errors << MealTime.invalid unless time
      attributes = items_attributes(items, errors)
      return invalid(errors) if errors.any?

      existing = FoodEntry.find_by(user_id:, client_request_id:)
      return existing_result(existing) if existing

      create(user_id:, client_request_id:, time:, attributes:)
    end

    # The columns of each item, or nil (with errors) when the list or an item is not acceptable.
    def self.items_attributes(items, errors)
      unless items.is_a?(Array) && (1..MAX_ITEMS).cover?(items.size)
        errors << { field: "items", code: "invalid" }
        return
      end

      parsed = items.each_with_index.map do |raw, index|
        input, item_errors = ItemInput.parse(raw, prefix: "items.#{index}.")
        errors.concat(item_errors)
        build(input, index, errors) if input
      end
      parsed unless errors.any?
    end

    def self.build(input, index, errors)
      attributes = ItemBuilder.from_input(input)
      errors << { field: "items.#{index}.catalog_item_id", code: "not_found" } unless attributes
      attributes
    end

    def self.existing_result(entry)
      return [ entry, false ] if entry.source == "manual"

      invalid([ { field: "client_request_id", code: "taken" } ])
    end

    def self.create(user_id:, client_request_id:, time:, attributes:)
      local_date = time.in_time_zone(MealTime.zone_for(user_id)).to_date
      entry = FoodEntry.transaction do
        meal = FoodEntry.create!(user_id:, client_request_id:, meal_at: time, local_date:, source: "manual", status: "confirmed", confirmed_at: Time.current)
        attributes.each { |item| FoodItem.create!(item.merge(food_entry: meal)) }
        RecalculateEntry.call(meal)
      end
      [ entry, true ]
    rescue ActiveRecord::RecordNotUnique
      # Another request with the same client_request_id won the race.
      existing_result(FoodEntry.find_by!(user_id:, client_request_id:))
    rescue ActiveRecord::RecordInvalid => error
      # The uniqueness validation saw the other request's commit before the index did. Any other failure is a bug.
      raise unless error.record.errors.of_kind?(:client_request_id, :taken)

      existing_result(FoodEntry.find_by!(user_id:, client_request_id:))
    end

    def self.invalid(errors) = Api::Errors.new(code: "validation_failed", details: errors)
    private_class_method :items_attributes, :build, :existing_result, :create, :invalid
  end
end

module Nutrition
  # One food of a meal, with its portion and, when the catalog knows it, its nutrient ranges.
  # Numbers are BigDecimal and never rounded here. An item with no catalog_item_id is unknown:
  # it has a portion and no nutrients, and the model is never asked for them.
  class FoodItem < ApplicationRecord
    self.table_name = "food_items"

    ORIGINS = %w[ai user].freeze

    belongs_to :food_entry, class_name: "Nutrition::FoodEntry", inverse_of: :items

    validates :display_name, presence: true
    validates :origin, inclusion: { in: ORIGINS }
    validates :confidence, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }, allow_nil: true

    def unknown? = catalog_item_id.nil?
  end
end

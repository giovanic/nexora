module FoodCatalog
  # One ingredient of a composition, with its grams per 100 g of the finished dish.
  class CompositionPart < ApplicationRecord
    self.table_name = "food_compositions"

    belongs_to :composition, class_name: "FoodCatalog::CatalogItem", foreign_key: :catalog_item_id, inverse_of: :parts
    belongs_to :ingredient, class_name: "FoodCatalog::CatalogItem", foreign_key: :ingredient_catalog_item_id

    validates :grams_per_100g, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  end
end

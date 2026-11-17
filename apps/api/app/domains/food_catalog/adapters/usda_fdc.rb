module FoodCatalog
  module Adapters
    # Reads db/catalog/usda_fdc.yml, the curated subset of USDA FoodData Central
    # (CC0 1.0), as the attributes of each CatalogItem.
    class UsdaFdc
      SOURCE = "usda_fdc".freeze

      def initialize(path)
        @doc = YAML.safe_load_file(path, permitted_classes: [], aliases: false)
      end

      # The source named by the file itself, checked against the allowed list by the loader.
      def source = @doc["source"]
      def license = @doc["license"]

      def items
        @doc.fetch("items").map do |item|
          {
            source: SOURCE, source_version: item.fetch("source_version").to_s, source_item_id: item.fetch("fdc_id").to_s,
            license:, name: item.fetch("name"), name_pt: item.fetch("name_pt"), kind: "ingredient", review: nil,
            nutrients_per_100g: CatalogItem::NUTRIENTS.to_h { |key| [ key, Float(item.fetch(key)) ] }
          }
        end
      end
    end
  end
end

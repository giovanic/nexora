module FoodCatalog
  module Adapters
    # Reads db/catalog/compositions.yml, the dishes written by the project. They are
    # the project's own estimates, marked for review by a nutritionist. The YAML
    # `notes` of a dish document the recipe in the file and are not stored.
    class ProjectCompositions
      SOURCE = "project".freeze

      Dish = Data.define(:attributes, :parts)

      def initialize(path)
        @doc = YAML.safe_load_file(path, permitted_classes: [], aliases: false)
      end

      def source = @doc["source"]
      def license = @doc["license"]

      # Item attributes (nutrients are computed by the loader) and the parts as [fdc_id string, grams BigDecimal].
      def dishes
        @doc.fetch("items").map do |dish|
          attributes = {
            source: SOURCE, source_version: @doc.fetch("source_version").to_s, source_item_id: dish.fetch("id"), license:,
            name: dish.fetch("name"), name_pt: dish.fetch("name_pt"), kind: "composition", review: @doc["review"]
          }
          parts = dish.fetch("parts").map { |part| [ part.fetch("fdc_id").to_s, BigDecimal(part.fetch("grams").to_s) ] }
          Dish.new(attributes:, parts:)
        end
      end
    end
  end
end

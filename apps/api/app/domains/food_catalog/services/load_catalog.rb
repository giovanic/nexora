module FoodCatalog
  # Loads the versioned catalog files into the database, in one transaction. Idempotent:
  # an item is found by (source, source_version, source_item_id) and updated in place,
  # so loading twice changes nothing. Refuses a file without license or from a source
  # outside ALLOWED_SOURCES, and a dish whose parts do not sum to 100 g.
  module LoadCatalog
    ALLOWED_SOURCES = %w[usda_fdc project].freeze
    DEFAULT_USDA_PATH = Rails.root.join("db/catalog/usda_fdc.yml")
    DEFAULT_COMPOSITIONS_PATH = Rails.root.join("db/catalog/compositions.yml")

    class Error < StandardError; end
    class MissingLicense < Error; end
    class UnknownSource < Error; end
    class InvalidComposition < Error; end

    def self.call(usda_path: DEFAULT_USDA_PATH, compositions_path: DEFAULT_COMPOSITIONS_PATH)
      usda = Adapters::UsdaFdc.new(usda_path)
      project = Adapters::ProjectCompositions.new(compositions_path)
      [ usda, project ].each { |adapter| check_file(adapter) }

      CatalogItem.transaction do
        usda.items.each { |attributes| upsert(attributes) }
        project.dishes.each { |dish| load_dish(dish) }
      end
    end

    def self.check_file(adapter)
      raise UnknownSource, "source #{adapter.source.inspect} is not allowed" unless ALLOWED_SOURCES.include?(adapter.source)
      raise MissingLicense, "#{adapter.source} has no license" if adapter.license.blank?
    end

    def self.upsert(attributes)
      key = attributes.slice(:source, :source_version, :source_item_id)
      item = CatalogItem.find_or_initialize_by(key)
      item.update!(attributes)
      item
    end

    def self.load_dish(dish)
      label = dish.attributes[:source_item_id]
      total = dish.parts.sum { |_, grams| grams }
      raise InvalidComposition, "#{label}: parts sum to #{total.to_s('F')} g, not 100 g" unless total == 100

      ingredients = ingredients_for(dish.parts.map(&:first), label)
      nutrients = CatalogItem::NUTRIENTS.to_h do |key|
        sum = dish.parts.sum { |fdc_id, grams| grams * BigDecimal(ingredients.fetch(fdc_id).nutrients_per_100g.fetch(key).to_s) / 100 }
        [ key, sum.round(4).to_f ]
      end

      composition = upsert(dish.attributes.merge(nutrients_per_100g: nutrients))
      composition.parts.where.not(ingredient_catalog_item_id: dish.parts.map { |fdc_id, _| ingredients.fetch(fdc_id).id }).destroy_all
      dish.parts.each do |fdc_id, grams|
        composition.parts.find_or_initialize_by(ingredient_catalog_item_id: ingredients.fetch(fdc_id).id).update!(grams_per_100g: grams)
      end
    end

    # The newest release of each USDA ingredient, by fdc_id.
    def self.ingredients_for(fdc_ids, label)
      found = CatalogItem.where(source: "usda_fdc", source_item_id: fdc_ids).order(:source_version).index_by(&:source_item_id)
      missing = fdc_ids - found.keys
      raise InvalidComposition, "#{label}: ingredient #{missing.join(', ')} is not in the catalog" if missing.any?

      found
    end
  end
end

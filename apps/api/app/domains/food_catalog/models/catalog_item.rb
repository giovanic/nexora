module FoodCatalog
  # One food of the reference catalog: a USDA ingredient or a dish of the project.
  # Holds no personal data. Nutrients are per 100 g: energy_kcal, protein_g, carbs_g, fat_g.
  class CatalogItem < ApplicationRecord
    self.table_name = "food_catalog"

    KINDS = %w[ingredient composition].freeze
    SOURCES = %w[usda_fdc project].freeze
    NUTRIENTS = %w[energy_kcal protein_g carbs_g fat_g].freeze

    has_many :parts, class_name: "FoodCatalog::CompositionPart", foreign_key: :catalog_item_id, inverse_of: :composition, dependent: :destroy

    before_validation { self.name_search = self.class.normalize(name_pt) if name_pt }

    validates :source, inclusion: { in: SOURCES }
    validates :kind, inclusion: { in: KINDS }
    validates :license, :source_version, :source_item_id, :name, :name_pt, presence: true

    # Runs a lookup that carries a typed or AI-given food name without the SQL log line,
    # which would print the name in its text and its binds (names of foods are health data).
    # The block runs exactly once. Every logger is silenced for the thread (the broadcast logger
    # itself and each logger it forwards to), by nesting their own thread-local silence.
    def self.unlogged(&block)
      loggers = [ logger, *(logger.broadcasts if logger.respond_to?(:broadcasts)) ].compact.select { |each| each.respond_to?(:silence) }
      loggers.reduce(block) { |inner, each| proc { each.silence(Logger::WARN, &inner) } }.call
    end

    # Lowercase and without accents, the form search and match compare in.
    def self.normalize(text)
      ActiveSupport::Inflector.transliterate(text.to_s.unicode_normalize(:nfc)).downcase.squish
    end
  end
end

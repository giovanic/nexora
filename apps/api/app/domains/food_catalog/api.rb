module FoodCatalog
  # The only entry point to FoodCatalog for other contexts and controllers. It returns
  # Data objects, never models. The catalog is reference data with no personal data.
  module Api
    # Minimum similarity for match, 0.45 to start, calibrated in Task 13 of the Food AI plan.
    MATCH_THRESHOLD = 0.45
    DEFAULT_PER_PAGE = 20
    MAX_PER_PAGE = 50
    # A huge offset is a scan of the table (and an out-of-range integer is a 500): the app narrows the term instead.
    MAX_PAGE = 1000
    MAX_TERM_LENGTH = 100

    CatalogItemInfo = Data.define(:id, :name_pt, :kind, :source)
    Page = Data.define(:items, :next_page)
    MatchInfo = Data.define(:catalog_item_id, :kind, :similarity)
    # per_100g: { energy_kcal:, protein_g:, carbs_g:, fat_g: }. The numbers are references, never a measurement.
    NutrientsInfo = Data.define(:per_100g, :source, :source_version, :source_item_id, :license, :kind)

    class << self
      # Whether the catalog has any item at all (false before food_catalog:load).
      def loaded?
        CatalogItem.exists?
      end

      # Page of CatalogItemInfo; per_page is capped at 50. A blank term finds nothing.
      def search(term:, page: 1, per_page: DEFAULT_PER_PAGE)
        SearchFoods.call(term:, page:, per_page:)
      end

      # Fields of a search request that are not acceptable, as [{ field:, code: }], never the values.
      def search_errors(term:, page: 1, per_page: DEFAULT_PER_PAGE)
        fields = []
        fields << "term" unless term.is_a?(String) && term.strip.present? && term.length <= MAX_TERM_LENGTH
        fields << "page" unless page.is_a?(Integer) && page.between?(1, MAX_PAGE)
        fields << "per_page" unless per_page.is_a?(Integer) && per_page >= 1
        fields.map { |field| { field:, code: "invalid" } }
      end

      # MatchInfo or nil. Compositions come before ingredients on the same score. threshold is for the calibration
      # of the evaluation only (evaluation/); the pipeline always uses MATCH_THRESHOLD.
      def match(name:, threshold: MATCH_THRESHOLD)
        MatchFood.call(name:, threshold:)
      end

      # NutrientsInfo, or nil for an unknown id.
      def nutrients_for(catalog_item_id:)
        return unless catalog_item_id.to_s.match?(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)

        item = CatalogItem.find_by(id: catalog_item_id)
        return unless item

        NutrientsInfo.new(per_100g: item.nutrients_per_100g.symbolize_keys, source: item.source, source_version: item.source_version,
                          source_item_id: item.source_item_id, license: item.license, kind: item.kind)
      end

      # CatalogItemInfo, or nil for an unknown id.
      def item(catalog_item_id:)
        return unless catalog_item_id.to_s.match?(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)

        found = CatalogItem.find_by(id: catalog_item_id)
        found && present(found)
      end

      def present(item)
        CatalogItemInfo.new(id: item.id, name_pt: item.name_pt, kind: item.kind, source: item.source)
      end
    end
  end
end

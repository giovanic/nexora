module FoodCatalog
  # Finds the catalog item whose name is closest to a food name given by the AI model,
  # or nil when nothing reaches Api::MATCH_THRESHOLD. On the same score a composition
  # wins over an ingredient.
  module MatchFood
    def self.call(name:, threshold: Api::MATCH_THRESHOLD)
      normalized = CatalogItem.normalize(name)
      return if normalized.empty?

      row = CatalogItem.unlogged do
        CatalogItem
            .where("name_search % :term", term: normalized)
            .where("similarity(name_search, :term) >= :threshold", term: normalized, threshold:)
            .order(Arel.sql(CatalogItem.sanitize_sql_array([ "similarity(name_search, ?) DESC", normalized ])),
                   Arel.sql("CASE kind WHEN 'composition' THEN 0 ELSE 1 END"), :id)
            .pick(:id, :kind, Arel.sql(CatalogItem.sanitize_sql_array([ "similarity(name_search, ?)", normalized ])))
      end
      return unless row

      Api::MatchInfo.new(catalog_item_id: row[0], kind: row[1], similarity: row[2].to_f.round(4))
    end
  end
end

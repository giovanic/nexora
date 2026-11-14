module FoodCatalog
  # Finds the catalog item whose name is closest to a food name given by the AI model,
  # or nil when nothing reaches Api::MATCH_THRESHOLD. On the same score a composition
  # wins over an ingredient.
  module MatchFood
    # Tie-break by rule: the AI model names food as it is on the plate, so when the name asked
    # for does not say cru or seco, an item whose name does loses RAW_PENALTY of similarity in
    # the ranking. The threshold still uses the plain similarity, and a raw name asked for wins.
    RAW_PENALTY = 0.15
    RAW_WORDS = %w[cru crua crus cruas seco seca secos secas].freeze
    RAW_SQL = "name_search ~ '\\m(#{RAW_WORDS.join("|")})\\M'".freeze
    RAW_QUERY = /\b(#{RAW_WORDS.join("|")})\b/

    def self.call(name:, threshold: Api::MATCH_THRESHOLD)
      normalized = CatalogItem.normalize(name)
      return if normalized.empty?

      penalty = normalized.match?(RAW_QUERY) ? 0 : RAW_PENALTY
      score = "similarity(name_search, ?) - CASE WHEN #{RAW_SQL} THEN #{penalty} ELSE 0 END"
      row = CatalogItem.unlogged do
        CatalogItem
            .where("name_search % :term", term: normalized)
            .where("similarity(name_search, :term) >= :threshold", term: normalized, threshold:)
            .order(Arel.sql(CatalogItem.sanitize_sql_array([ "#{score} DESC", normalized ])),
                   Arel.sql("CASE kind WHEN 'composition' THEN 0 ELSE 1 END"), :id)
            .pick(:id, :kind, Arel.sql(CatalogItem.sanitize_sql_array([ "similarity(name_search, ?)", normalized ])))
      end
      return unless row

      Api::MatchInfo.new(catalog_item_id: row[0], kind: row[1], similarity: row[2].to_f.round(4))
    end
  end
end

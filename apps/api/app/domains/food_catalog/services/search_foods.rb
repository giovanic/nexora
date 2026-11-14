module FoodCatalog
  # Searches the catalog by name, ignoring case and accents. Matches a typed fragment
  # (a pattern the trigram index serves) or a close word (word similarity), best first,
  # compositions before ingredients on a tie. Paginated, with a hard cap on page size.
  module SearchFoods
    WORD_SIMILARITY_FLOOR = 0.4

    def self.call(term:, page: 1, per_page: Api::DEFAULT_PER_PAGE)
      normalized = CatalogItem.normalize(term).first(Api::MAX_TERM_LENGTH)
      page = [ page.to_i, 1 ].max
      per_page = per_page.to_i.clamp(1, Api::MAX_PER_PAGE)
      return Api::Page.new(items: [], next_page: nil) if normalized.empty?

      rows = CatalogItem.unlogged { scope(normalized).offset((page - 1) * per_page).limit(per_page + 1).to_a }
      Api::Page.new(items: rows.first(per_page).map { |item| Api.present(item) }, next_page: rows.size > per_page ? page + 1 : nil)
    end

    def self.scope(normalized)
      like = "%#{CatalogItem.sanitize_sql_like(normalized)}%"
      CatalogItem
        .where("name_search LIKE :like OR (:term <% name_search AND word_similarity(:term, name_search) >= :floor)",
               like:, term: normalized, floor: WORD_SIMILARITY_FLOOR)
        .order(Arel.sql(CatalogItem.sanitize_sql_array([ "word_similarity(?, name_search) DESC", normalized ])),
               Arel.sql("CASE kind WHEN 'composition' THEN 0 ELSE 1 END"), :name_pt, :id)
    end
    private_class_method :scope
  end
end

require_relative "metrics"

module Evaluation
  # How well the names of the annotations find their food in the catalog, with no provider involved: the match
  # rate at the current MATCH_THRESHOLD and a suggested threshold. Inside Rails (bin/rails runner).
  #
  # annotations["catalog_truth"] maps each expected name to the catalog item (name_pt) a person accepts as the
  # right ones (one name or a list), or to nil when the catalog has nothing acceptable. That is a judgement by the project, not data of
  # the dataset: it is what lets the sweep tell a right match from a wrong one.
  module CatalogCheck
    LOWEST = 0.30 # below this pg_trgm does not even offer a candidate
    THRESHOLDS = (0.30..0.70).step(0.05).map { _1.round(2) }.freeze

    module_function

    # Returns { names:, occurrences:, table:, suggested:, current:, current_threshold: }.
    def call(annotations)
      truth = annotations.fetch("catalog_truth")
      listed = annotations.fetch("annotations").values.flat_map { |entry| (entry["items"] || []).map { _1["name"] } }
      names = listed.uniq.sort.map { |name| row(name, truth) }
      table = Metrics.threshold_table(names, THRESHOLDS)
      current_threshold = FoodCatalog::Api::MATCH_THRESHOLD
      matched = ->(name) { names.find { _1[:name] == name }[:similarity].to_f >= current_threshold }
      {
        names:, table:, suggested: Metrics.suggest_threshold(table), current_threshold:,
        current: Metrics.threshold_table(names, [ current_threshold ]).first,
        occurrences: { total: listed.size, matched: listed.count { matched.call(_1) } }
      }
    end

    def row(name, truth)
      found = FoodCatalog::Api.match(name:, threshold: LOWEST)
      best = found && FoodCatalog::Api.item(catalog_item_id: found.catalog_item_id)
      accepted = Array(truth.fetch(name) { raise ArgumentError, "catalog_truth has no entry for an expected name: #{name}" })
      { name:, best: found&.catalog_item_id, best_name: best&.name_pt, similarity: found&.similarity,
        truth: accepted.map { catalog_id(_1) }, truth_name: accepted.empty? ? nil : accepted.join(" / ") }
    end

    # A name in the truth map that the catalog does not have is a mistake of the annotation: say so, loudly.
    def catalog_id(name_pt)
      FoodCatalog::Api.search(term: name_pt, per_page: 10).items.find { _1.name_pt == name_pt }&.id ||
        raise(ArgumentError, "catalog_truth names an item that is not in the catalog: #{name_pt}")
    end
  end
end

module FoodAi
  # The model's free text (item name, preparation, household measure) must carry neither a calorie or energy
  # figure nor a judgment of the food. The list is scripts/language_denylist_model_text.txt: the judgment
  # expressions (and clearly judgmental words) of the product's denylist, without the entries that are body parts
  # or common food words ("barriga de porco" is a food). scripts/check_language.py reads the same file format
  # with the same rules: no case, no accents (NFKD without combining marks),
  # whole word or phrase, a trailing "*" for a prefix. The list is read once. If it cannot be read the error
  # propagates (the text is never let through), and it names no value.
  module LanguageDenylist
    PATH = Rails.root.join("../../scripts/language_denylist_model_text.txt")
    # Calories and energy: kcal, cal, kj, caloria(s), quilocaloria(s), energia, energy. Letters around the term
    # count as part of the word ("calabresa", "local" are foods), digits do not ("50kcal").
    ENERGY = /(?<!\p{L})(?:k?cal|kj)(?!\p{L})|(?<!\p{L})(?:calori|quilocal|energi|energet|energy)/

    class << self
      def match?(text)
        normalized = normalize(text)
        normalized.match?(ENERGY) || patterns.any? { |pattern| pattern.match?(normalized) }
      end

      def normalize(text)
        text.unicode_normalize(:nfkd).gsub(/\p{Mn}/, "").downcase
      end

      private

      def patterns
        @patterns ||= File.readlines(PATH, encoding: "UTF-8").map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
                          .map { |line| compile(normalize(line)) }.freeze
      end

      def compile(term)
        prefix = term.end_with?("*")
        body = term.delete_suffix("*").split.map { |part| Regexp.escape(part) }.join('\s+')
        Regexp.new("(?<![\\p{Word}])#{body}#{prefix ? '\p{Word}*' : '(?![\p{Word}])'}")
      end
    end
  end
end

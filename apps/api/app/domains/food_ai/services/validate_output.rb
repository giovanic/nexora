module FoodAi
  # Strict validation of the model's structured answer (AI_ARCHITECTURE, "Saída estruturada").
  # The provider may not enforce limits, so this always runs on the full schema: exact fields,
  # no extra field, no calories or energy key at any depth, ranges, closed lists, plain text.
  # Raises InvalidOutputError with a code only; the offending value is never kept or logged.
  class ValidateOutput
    IMAGE_QUALITIES = %w[good poor unreadable].freeze
    NOTE_CODES = %w[possible_added_fat possible_hidden_ingredients partial_view low_light].freeze
    MAX_ITEMS = 15
    MAX_NAME = 80
    MAX_PREPARATION = 60
    MAX_HOUSEHOLD_MEASURE = 60
    MIN_GRAMS = 1
    MAX_GRAMS = 2000

    FORBIDDEN_KEY = /kcal|calor|energy/i
    URL = %r{https?://|ftp://|www\.|\b[\w-]+\.(?:com|org|net|br|io|gov|edu|app|dev|co|me|ly|xyz|info)\b}i
    MARKUP = /[<>]/
    CONTROL = /[[:cntrl:]]/

    ROOT_KEYS = %w[contains_food image_quality items note_codes].freeze
    ITEM_KEYS = %w[name preparation confidence portion hidden_ingredients_possible].freeze
    PORTION_KEYS = %w[grams_min grams_likely grams_max household_measure].freeze

    def self.call(payload) = new(payload).call

    def initialize(payload)
      @payload = payload
    end

    def call
      root = hash!(normalize(@payload))
      reject_forbidden_keys!(root)
      exact_keys!(root, ROOT_KEYS)

      ValidatedOutput.new(
        contains_food: boolean!(root["contains_food"]),
        image_quality: one_of!(root["image_quality"], IMAGE_QUALITIES),
        items: items!(root["items"]),
        note_codes: note_codes!(root["note_codes"])
      )
    end

    private

    def fail!(code) = raise(InvalidOutputError, code)

    # Symbol keys are accepted; nothing else is coerced.
    def normalize(value)
      case value
      when Hash then value.to_h { |k, v| [ k.to_s, normalize(v) ] }
      when Array then value.map { |v| normalize(v) }
      else value
      end
    end

    def hash!(value)
      fail!("wrong_type") unless value.is_a?(Hash)
      value
    end

    def reject_forbidden_keys!(value)
      case value
      when Hash
        value.each do |key, inner|
          fail!("forbidden_field") if key.match?(FORBIDDEN_KEY)
          reject_forbidden_keys!(inner)
        end
      when Array then value.each { |inner| reject_forbidden_keys!(inner) }
      end
    end

    def exact_keys!(hash, keys)
      fail!("unexpected_field") unless (hash.keys - keys).empty?
      fail!("missing_field") unless (keys - hash.keys).empty?
    end

    def boolean!(value)
      fail!("wrong_type") unless [ true, false ].include?(value)
      value
    end

    def one_of!(value, list)
      fail!("wrong_type") unless value.is_a?(String)
      fail!("unknown_value") unless list.include?(value)
      value
    end

    def number!(value, range)
      fail!("wrong_type") unless value.is_a?(Numeric) && !value.is_a?(Complex)
      fail!("out_of_range") unless value.to_f.finite? && range.cover?(value)
      value
    end

    def text!(value, max)
      fail!("wrong_type") unless value.is_a?(String)
      fail!("invalid_text") if value.strip.empty? || value.length > max
      fail!("invalid_text") if value.match?(CONTROL) || value.match?(MARKUP) || value.match?(URL)
      value
    end

    def items!(value)
      fail!("wrong_type") unless value.is_a?(Array)
      fail!("too_many_items") if value.size > MAX_ITEMS

      value.map { |item| item!(item) }
    end

    def item!(raw)
      item = hash!(raw)
      exact_keys!(item, ITEM_KEYS)

      ValidatedOutput::Item.new(
        name: text!(item["name"], MAX_NAME),
        preparation: text!(item["preparation"], MAX_PREPARATION),
        confidence: number!(item["confidence"], 0..1),
        portion: portion!(item["portion"]),
        hidden_ingredients_possible: boolean!(item["hidden_ingredients_possible"])
      )
    end

    def portion!(raw)
      portion = hash!(raw)
      exact_keys!(portion, PORTION_KEYS)

      min = number!(portion["grams_min"], MIN_GRAMS..MAX_GRAMS)
      likely = number!(portion["grams_likely"], MIN_GRAMS..MAX_GRAMS)
      max = number!(portion["grams_max"], MIN_GRAMS..MAX_GRAMS)
      fail!("out_of_range") unless min <= likely && likely <= max

      ValidatedOutput::Portion.new(grams_min: min, grams_likely: likely, grams_max: max,
                                   household_measure: text!(portion["household_measure"], MAX_HOUSEHOLD_MEASURE))
    end

    def note_codes!(value)
      fail!("wrong_type") unless value.is_a?(Array)

      value.map { |code| one_of!(code, NOTE_CODES) }
    end
  end
end

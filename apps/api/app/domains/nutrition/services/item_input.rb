require "bigdecimal"

module Nutrition
  # What a person sends for an item (to add one, or to register a meal by hand), checked and turned into
  # grams and a name or a catalog id. Errors name the field and a code, never the value.
  module ItemInput
    GRAMS = BigDecimal("1")..BigDecimal("2000")
    NAME_MAX = 80
    Parsed = Data.define(:catalog_item_id, :free_text_name, :grams_min, :grams_likely, :grams_max)

    # raw: a Hash with symbol keys. prefix: "items.0." for an item of a list. Returns [Parsed, []] or [nil, errors].
    def self.parse(raw, prefix: "")
      return [ nil, [ { field: prefix.delete_suffix("."), code: "invalid" } ] ] unless raw.is_a?(Hash)

      errors = []
      catalog_item_id, free_text_name = source(raw, errors)
      likely = grams(raw[:grams_likely], "grams_likely", errors, required: true)
      min = grams(raw[:grams_min], "grams_min", errors) || likely
      max = grams(raw[:grams_max], "grams_max", errors) || likely
      errors << { field: "grams_min", code: "invalid" } if likely && min && min > likely
      errors << { field: "grams_max", code: "invalid" } if likely && max && max < likely
      return [ nil, errors.map { |error| error.merge(field: "#{prefix}#{error[:field]}") } ] if errors.any?

      [ Parsed.new(catalog_item_id:, free_text_name:, grams_min: min, grams_likely: likely, grams_max: max), [] ]
    end

    # One grams value in 1..2000 g, as a BigDecimal rounded to 0.01 g. Only a JSON number counts.
    # nil, with no error, when it is absent and not required.
    def self.grams(value, field, errors, required: false)
      if value.nil?
        errors << { field:, code: "required" } if required
        return
      end
      return fail_with(errors, field, "invalid") unless value.is_a?(Numeric) && (!value.is_a?(Float) || value.finite?)

      number = BigDecimal(value.to_s)
      return fail_with(errors, field, "out_of_range") unless GRAMS.cover?(number)

      number.round(2)
    end

    # Exactly one of a catalog id and a name. Returns [catalog_item_id, free_text_name].
    def self.source(raw, errors)
      id = raw[:catalog_item_id]
      name = raw[:free_text_name]
      return [ nil, nil ] if both_or_none(id, name, errors)
      unless id.nil?
        fail_with(errors, "catalog_item_id", "invalid") unless id.is_a?(String)
        return [ id, nil ]
      end

      text = name.is_a?(String) ? name.strip : ""
      code = text.empty? ? "invalid" : ("too_long" if text.length > NAME_MAX)
      errors << { field: "free_text_name", code: } if code
      [ nil, text ]
    end

    def self.both_or_none(id, name, errors)
      if id.nil? && name.nil?
        errors << { field: "catalog_item_id", code: "required" }
      elsif !id.nil? && !name.nil?
        errors << { field: "catalog_item_id", code: "conflict" }
      end
      errors.any?
    end

    def self.fail_with(errors, field, code)
      errors << { field:, code: }
      nil
    end
    private_class_method :grams, :source, :both_or_none, :fail_with
  end
end

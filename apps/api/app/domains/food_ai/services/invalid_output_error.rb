module FoodAi
  # The answer is outside the schema, or the model refused. One retry, then the analysis fails.
  class InvalidOutputError < ProviderError
    CODES = %w[not_an_object missing_field unexpected_field wrong_type out_of_range too_many_items
               invalid_text unknown_value forbidden_field invalid_encoding duplicate_value refusal].freeze
  end
end

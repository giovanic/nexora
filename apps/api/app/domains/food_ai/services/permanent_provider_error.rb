module FoodAi
  # Do not try again: the request itself was refused (4xx other than 429).
  class PermanentProviderError < ProviderError
    CODES = %w[bad_request unauthorized model_unavailable unsupported_model].freeze
  end
end

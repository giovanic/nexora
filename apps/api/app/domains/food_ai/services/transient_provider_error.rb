module FoodAi
  # Try again: timeout, 429 and 5xx.
  class TransientProviderError < ProviderError
    CODES = %w[timeout rate_limited provider_unavailable].freeze
  end
end

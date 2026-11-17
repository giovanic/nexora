module FoodAi
  # What an adapter returns. payload is the model's parsed JSON, still unvalidated: it goes
  # through ValidateOutput before anything uses it. Never log it.
  ProviderResponse = Data.define(:payload, :provider, :model, :input_tokens, :output_tokens, :cost_usd)
end

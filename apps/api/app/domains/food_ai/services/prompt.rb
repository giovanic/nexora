module FoodAi
  # A registered prompt: its identifier, the schema version it answers to, the instructions
  # and the full output JSON Schema (adapters may weaken it for their provider).
  Prompt = Data.define(:version, :schema_version, :body, :schema)
end

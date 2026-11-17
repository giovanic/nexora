# FoodAi.adapter is the provider of the active configuration. Examples get none by default, and
# assign a double, so nothing reaches a network.
module FoodAiAdapter
  # Plays its steps in order, the last one repeating: a payload Hash answers, an Exception is raised.
  class ScriptedAdapter < FoodAi::Adapters::FakeAdapter
    def initialize(steps:, **options)
      super(payload: {}, **options)
      @steps = steps
    end

    def analyze(image:, content_type:, prompt:, schema:)
      @calls += 1
      step = @steps[[ @calls - 1, @steps.size - 1 ].min]
      raise step if step.is_a?(Exception)

      FoodAi::ProviderResponse.new(payload: step, provider: @provider, model: @model, input_tokens: @input_tokens,
                                   output_tokens: @output_tokens, cost_usd: @cost_usd)
    end
  end

  RICE = {
    "contains_food" => true, "image_quality" => "good", "note_codes" => [ "partial_view" ],
    "items" => [ { "name" => "rice", "preparation" => "cooked", "confidence" => 0.9, "hidden_ingredients_possible" => false,
                   "portion" => { "grams_min" => 120, "grams_likely" => 150, "grams_max" => 180, "household_measure" => "1 scoop" } } ]
  }.freeze
  NO_FOOD = { "contains_food" => false, "image_quality" => "good", "items" => [], "note_codes" => [] }.freeze
  EMPTY_FOOD = { "contains_food" => true, "image_quality" => "good", "items" => [], "note_codes" => [] }.freeze

  def use_adapter(adapter)
    FoodAi.adapter = adapter
  end

  def scripted(*steps, **options) = use_adapter(ScriptedAdapter.new(steps:, **options))
end

RSpec.configure do |config|
  config.include FoodAiAdapter
  config.after { FoodAi.adapter = nil }
end

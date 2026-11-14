module FoodAi
  # The model's answer after ValidateOutput: only these fields, in range, as plain values.
  ValidatedOutput = Data.define(:contains_food, :image_quality, :items, :note_codes)

  class ValidatedOutput
    Item = Data.define(:name, :preparation, :confidence, :portion, :hidden_ingredients_possible)
    Portion = Data.define(:grams_min, :grams_likely, :grams_max, :household_measure)
  end
end

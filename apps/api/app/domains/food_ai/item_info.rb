module FoodAi
  # One food the model saw, with its portion as a range of grams. Only what Nutrition needs.
  ItemInfo = Data.define(:name, :preparation, :confidence, :grams_min, :grams_likely, :grams_max, :household_measure, :hidden_ingredients_possible)
end

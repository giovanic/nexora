require "rails_helper"

# Nutrition::Api.estimate: the arithmetic of a meal without writing one (used by the evaluation).
RSpec.describe "Nutrition::Api.estimate" do
  def add_food(name, **nutrients)
    FoodCatalog::CatalogItem.create!(source: "usda_fdc", source_version: "v1", source_item_id: SecureRandom.hex(3), license: "CC0-1.0", name:, name_pt: name,
                                     kind: "ingredient", nutrients_per_100g: nutrients.transform_keys(&:to_s))
  end

  let(:rice) { add_food("Arroz", energy_kcal: 130, protein_g: 2.7, carbs_g: 28, fat_g: 0.3) }

  it "gives the ranges the entry view gives: calories to the ten, macros to the gram, always min, likely and max" do
    result = Nutrition::Api.estimate(items: [ { catalog_item_id: rice.id, grams_min: 100, grams_likely: 150, grams_max: 200 } ])

    expect(result).to be_a(Nutrition::Api::EstimateInfo)
    expect(result.ranges).to include(calories_min: 130, calories_likely: 200, calories_max: 260,
                                     protein_g_min: 3, protein_g_likely: 4, protein_g_max: 5,
                                     carbs_g_min: 28, carbs_g_likely: 42, carbs_g_max: 56,
                                     fat_g_min: 0, fat_g_likely: 0, fat_g_max: 1)
    expect(result).to have_attributes(estimate_partial: false, unknown_items_count: 0)
  end

  it "sums the known items and counts the others as unknown, making the estimate partial" do
    result = Nutrition::Api.estimate(items: [
      { catalog_item_id: rice.id, grams_min: 100, grams_likely: 100, grams_max: 100 },
      { catalog_item_id: nil, grams_min: 50, grams_likely: 60, grams_max: 70 },
      { catalog_item_id: SecureRandom.uuid, grams_min: 50, grams_likely: 60, grams_max: 70 }
    ])

    expect(result.ranges).to include(calories_min: 130, calories_likely: 130, calories_max: 130)
    expect(result).to have_attributes(estimate_partial: true, unknown_items_count: 2)
  end

  it "has no numbers when no item is known, and none when there is no item" do
    unknown = Nutrition::Api.estimate(items: [ { catalog_item_id: nil, grams_min: 1, grams_likely: 2, grams_max: 3 } ])
    empty = Nutrition::Api.estimate(items: [])

    expect(unknown.ranges).to include(calories_min: nil, calories_likely: nil, calories_max: nil)
    expect(unknown.estimate_partial).to be(true)
    expect(empty).to have_attributes(estimate_partial: false, unknown_items_count: 0)
  end

  it "writes nothing" do
    rice
    expect { Nutrition::Api.estimate(items: [ { catalog_item_id: rice.id, grams_min: 1, grams_likely: 2, grams_max: 3 } ]) }
      .not_to change { [ Nutrition::FoodItem.count, Nutrition::FoodEntry.count ] }
  end
end

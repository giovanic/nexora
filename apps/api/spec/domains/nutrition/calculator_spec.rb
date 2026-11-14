require "rails_helper"

RSpec.describe Nutrition::Calculator do
  let(:per_100g) { { energy_kcal: BigDecimal("130"), protein_g: BigDecimal("2.7"), carbs_g: BigDecimal("28"), fat_g: BigDecimal("0.3") } }

  def item(grams_min: 120, grams_likely: 150, grams_max: 180, per: per_100g)
    described_class.item(per_100g: per, grams_min:, grams_likely:, grams_max:)
  end

  it "item range is per_100g times grams min, likely and max" do
    result = item

    expect(result).to include(calories_min: BigDecimal("156"), calories_likely: BigDecimal("195"), calories_max: BigDecimal("234"),
                              protein_g_min: BigDecimal("3.24"), protein_g_likely: BigDecimal("4.05"), protein_g_max: BigDecimal("4.86"),
                              carbs_g_min: BigDecimal("33.6"), carbs_g_likely: BigDecimal("42"), carbs_g_max: BigDecimal("50.4"),
                              fat_g_min: BigDecimal("0.36"), fat_g_likely: BigDecimal("0.45"), fat_g_max: BigDecimal("0.54"))
    expect(result.values).to all(be_a(BigDecimal))
  end

  it "does not round the numbers" do
    expect(item(grams_likely: 33, grams_min: 33, grams_max: 33)[:calories_likely]).to eq(BigDecimal("42.9"))
  end

  describe ".meal" do
    def known(...) = Nutrition::FoodItem.new(**item(...), catalog_item_id: SecureRandom.uuid)

    it "meal sums only known items and flags a partial estimate" do
      unknown = Nutrition::FoodItem.new(display_name: "mystery", catalog_item_id: nil)

      meal = described_class.meal([ known, known(grams_min: 100, grams_likely: 100, grams_max: 100), unknown ])

      expect(meal).to include(calories_min: BigDecimal("286"), calories_likely: BigDecimal("325"), calories_max: BigDecimal("364"),
                              estimate_partial: true, unknown_count: 1)
    end

    it "meal without known items has null calories" do
      meal = described_class.meal([ Nutrition::FoodItem.new(display_name: "mystery", catalog_item_id: nil) ])

      expect(meal).to include(calories_min: nil, calories_likely: nil, calories_max: nil, protein_g_min: nil, estimate_partial: true, unknown_count: 1)
      expect(described_class.meal([])).to include(calories_min: nil, estimate_partial: false, unknown_count: 0)
    end

    it "a meal of known items is not partial" do
      expect(described_class.meal([ known ])).to include(estimate_partial: false, unknown_count: 0)
    end
  end
end

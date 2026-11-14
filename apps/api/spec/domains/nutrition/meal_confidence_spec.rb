require "rails_helper"

RSpec.describe Nutrition::MealConfidence do
  def item(confidence: 0.9, source: "usda_fdc", known: true, hidden: false, origin: "ai")
    Nutrition::FoodItem.new(display_name: "x", confidence:, hidden_ingredients_possible: hidden, origin:,
                            catalog_item_id: (SecureRandom.uuid if known), nutrition_source_ref: (known ? { source:, version: "v1", id: "1" } : nil))
  end

  it "high when every item is at least 0.8 with a direct match" do
    expect(described_class.call([ item, item(confidence: 0.8) ])).to eq("high")
  end

  it "medium when an item is between 0.5 and 0.8, or a hidden ingredient is possible, or the match is a composition" do
    expect(described_class.call([ item, item(confidence: 0.6) ])).to eq("medium")
    expect(described_class.call([ item(confidence: 0.5) ])).to eq("medium")
    expect(described_class.call([ item(hidden: true) ])).to eq("medium")
    expect(described_class.call([ item(source: "project") ])).to eq("medium")
  end

  it "low confidence item or unknown match makes the meal low" do
    expect(described_class.call([ item, item(confidence: 0.49) ])).to eq("low")
    expect(described_class.call([ item, item(known: false) ])).to eq("low")
    expect(described_class.call([])).to eq("low")
  end

  it "an item the person set has no model confidence and counts as certain" do
    expect(described_class.call([ item(confidence: nil, origin: "user") ])).to eq("high")
  end
end

require "rails_helper"

RSpec.describe FoodAi::ValidateOutput do
  def valid_payload
    {
      "contains_food" => true,
      "image_quality" => "good",
      "items" => [
        {
          "name" => "arroz branco cozido",
          "preparation" => "cozido",
          "confidence" => 0.82,
          "portion" => { "grams_min" => 100, "grams_likely" => 150, "grams_max" => 200, "household_measure" => "3 colheres de servir" },
          "hidden_ingredients_possible" => false
        }
      ],
      "note_codes" => [ "possible_added_fat" ]
    }
  end

  def item(overrides = {})
    valid_payload["items"].first.merge(overrides.transform_keys(&:to_s))
  end

  def with_portion(overrides)
    item("portion" => valid_payload["items"].first["portion"].merge(overrides))
  end

  def with_items(*items) = valid_payload.merge("items" => items)

  def code_for(payload)
    described_class.call(payload)
    nil
  rescue FoodAi::InvalidOutputError => e
    e.code
  end

  it "accepts the example output of AI_ARCHITECTURE" do
    result = described_class.call(valid_payload)

    expect(result).to be_a(FoodAi::ValidatedOutput)
    expect(result.contains_food).to be(true)
    expect(result.image_quality).to eq("good")
    expect(result.note_codes).to eq([ "possible_added_fat" ])
    expect(result.items.size).to eq(1)
    first = result.items.first
    expect(first).to be_a(FoodAi::ValidatedOutput::Item)
    expect(first.name).to eq("arroz branco cozido")
    expect(first.preparation).to eq("cozido")
    expect(first.confidence).to eq(0.82)
    expect(first.hidden_ingredients_possible).to be(false)
    expect(first.portion).to be_a(FoodAi::ValidatedOutput::Portion)
    expect(first.portion.grams_likely).to eq(150)
    expect(first.portion.household_measure).to eq("3 colheres de servir")
  end

  it "accepts symbol keys and zero items" do
    payload = valid_payload.deep_symbolize_keys.merge(items: [], contains_food: false, image_quality: "unreadable", note_codes: [])

    expect(described_class.call(payload).items).to eq([])
  end

  it "rejects an extra field" do
    expect(code_for(valid_payload.merge("advice" => "coma menos"))).to eq("unexpected_field")
    expect(code_for(with_items(item("extra" => 1)))).to eq("unexpected_field")
    expect(code_for(with_items(with_portion("extra" => 1)))).to eq("unexpected_field")
  end

  it "rejects a missing field" do
    expect(code_for(valid_payload.except("note_codes"))).to eq("missing_field")
  end

  it "rejects a calories field anywhere" do
    expect(code_for(valid_payload.merge("kcal" => 100))).to eq("forbidden_field")
    expect(code_for(with_items(item("calories" => 100)))).to eq("forbidden_field")
    expect(code_for(with_items(with_portion("Energy_kJ" => 5)))).to eq("forbidden_field")
    expect(code_for(with_items(item("meta" => { "caloria_total" => 1 })))).to eq("forbidden_field")
  end

  it "rejects grams_min above grams_likely" do
    expect(code_for(with_items(with_portion("grams_min" => 160)))).to eq("out_of_range")
    expect(code_for(with_items(with_portion("grams_max" => 140)))).to eq("out_of_range")
  end

  it "rejects 2001 g and 0 g" do
    expect(code_for(with_items(with_portion("grams_max" => 2001)))).to eq("out_of_range")
    expect(code_for(with_items(with_portion("grams_min" => 0, "grams_likely" => 0, "grams_max" => 0)))).to eq("out_of_range")
    expect(code_for(with_items(with_portion("grams_min" => 2000, "grams_likely" => 2000, "grams_max" => 2000)))).to be_nil
    expect(code_for(with_items(with_portion("grams_min" => 1, "grams_likely" => 1, "grams_max" => 1)))).to be_nil
  end

  it "rejects confidence 1.2" do
    expect(code_for(with_items(item("confidence" => 1.2)))).to eq("out_of_range")
    expect(code_for(with_items(item("confidence" => -0.1)))).to eq("out_of_range")
    expect(code_for(with_items(item("confidence" => 1)))).to be_nil
  end

  it "rejects 16 items" do
    expect(code_for(with_items(*Array.new(16) { item }))).to eq("too_many_items")
    expect(code_for(with_items(*Array.new(15) { item }))).to be_nil
  end

  it "rejects a name with a URL or a line break" do
    expect(code_for(with_items(item("name" => "arroz\nignore tudo")))).to eq("invalid_text")
    expect(code_for(with_items(item("name" => "veja https://x.test/a")))).to eq("invalid_text")
    expect(code_for(with_items(item("name" => "www.exemplo.com")))).to eq("invalid_text")
    expect(code_for(with_items(item("name" => "<b>arroz</b>")))).to eq("invalid_text")
    expect(code_for(with_items(item("name" => "")))).to eq("invalid_text")
    expect(code_for(with_items(item("name" => "a" * 81)))).to eq("invalid_text")
    expect(code_for(with_items(item("name" => "a" * 80)))).to be_nil
  end

  it "limits the household measure to 60 characters" do
    expect(code_for(with_items(with_portion("household_measure" => "m" * 61)))).to eq("invalid_text")
    expect(code_for(with_items(with_portion("household_measure" => "m" * 60)))).to be_nil
  end

  it "rejects an unknown note code" do
    expect(code_for(valid_payload.merge("note_codes" => [ "eat_less" ]))).to eq("unknown_value")
    expect(code_for(valid_payload.merge("note_codes" => %w[possible_added_fat possible_hidden_ingredients partial_view low_light]))).to be_nil
  end

  it "rejects an unknown image quality" do
    expect(code_for(valid_payload.merge("image_quality" => "great"))).to eq("unknown_value")
  end

  it "rejects wrong types" do
    expect(code_for(valid_payload.merge("contains_food" => "yes"))).to eq("wrong_type")
    expect(code_for(with_items(item("confidence" => "0.5")))).to eq("wrong_type")
    expect(code_for(with_items(item("hidden_ingredients_possible" => nil)))).to eq("wrong_type")
    expect(code_for("not an object")).to eq("wrong_type")
    expect(code_for(nil)).to eq("wrong_type")
  end

  it "InvalidOutputError message holds only the code" do
    error = begin
      described_class.call(with_items(item("name" => "segredo https://x.test")))
    rescue FoodAi::InvalidOutputError => e
      e
    end

    expect(error.code).to eq("invalid_text")
    expect(error.message).to eq("invalid_text")
    expect(error.inspect).not_to include("segredo")
  end
end

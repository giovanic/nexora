require "rails_helper"
require "tmpdir"
require "support/image_fixtures"
require "support/food_ai_adapter"
require Rails.root.join("../../evaluation/runner").to_s

# The runner uses the real pipeline pieces with a scripted provider: no network, and no row is written.
RSpec.describe Evaluation::Runner do
  def add_food(name, kind: "ingredient", **nutrients)
    FoodCatalog::CatalogItem.create!(source: "usda_fdc", source_version: "v1", source_item_id: SecureRandom.hex(3), license: "CC0-1.0", name:, name_pt: name,
                                     kind:, nutrients_per_100g: nutrients.transform_keys(&:to_s))
  end

  def payload(items: [ [ "arroz branco cozido", 90, 100, 120 ], [ "salada misteriosa", 20, 30, 40 ] ], contains_food: true, quality: "good", **extra)
    { "contains_food" => contains_food, "image_quality" => quality, "note_codes" => [],
      "items" => items.map do |name, min, likely, max|
        { "name" => name, "preparation" => "", "confidence" => 0.8, "hidden_ingredients_possible" => false,
          "portion" => { "grams_min" => min, "grams_likely" => likely, "grams_max" => max, "household_measure" => "1 porção" } }
      end }.merge(extra)
  end

  let(:dir) { Dir.mktmpdir("evaluation-runner") }
  let(:clock_values) { [ 10.0, 11.5 ].cycle }
  let(:waits) { [] }
  let(:entry) { { "id" => "img-1", "file" => "img-1.jpg" } }
  let(:annotations) do
    { "annotations" => { "img-1" => { "expect" => "food", "items" => [ { "name" => "arroz branco cozido", "grams" => 105 }, { "name" => "ovo cozido", "grams" => 50 } ] } } }
  end
  let!(:rice) { add_food("Arroz branco cozido", energy_kcal: 130, protein_g: 2.7, carbs_g: 28, fat_g: 0.3) }
  let(:runner) do
    described_class.new(manifest: { "images" => [ entry ] }, annotations:, dir:, sleeper: ->(seconds) { waits << seconds }, clock: -> { clock_values.next })
  end

  before { File.binwrite(File.join(dir, "img-1.jpg"), ImageFixtures.jpeg) }
  after { FileUtils.remove_entry(dir) }

  def adapter(*steps, **options) = FoodAiAdapter::ScriptedAdapter.new(steps:, cost_usd: BigDecimal("0.0021"), input_tokens: 1200, output_tokens: 300, **options)

  it "answers with the codes, numbers and keys of one photo: catalog keys, grams, latency, tokens and cost" do
    record = runner.evaluate(entry, adapter: adapter(payload))

    expect(record).to include(image: "img-1", expect: "food", status: "succeeded", valid: true, error: nil, latency: 1.5, cost: BigDecimal("0.0021"),
                              input_tokens: 1200, output_tokens: 300, matched_items: 1, unknown_items: 1, estimate_partial: true, attempts: 1)
    expect(record[:predicted_keys].first).to eq("catalog:#{rice.id}")
    expect(record[:predicted_keys].last).to eq("text:salada misteriosa")
    expect(record[:predicted_items].first).to include(key: "catalog:#{rice.id}", grams_min: 90, grams_likely: 100, grams_max: 120)
    expect(record[:expected_items].first).to eq(key: "catalog:#{rice.id}", grams: 105)
    expect(record[:expected_keys]).to eq([ "catalog:#{rice.id}", "text:ovo cozido" ])
  end

  it "keeps nothing the model wrote beyond item texts for the injection check, and no image" do
    record = runner.evaluate(entry, adapter: adapter(payload))

    expect(record.keys).not_to include(:payload, :raw, :bytes, :image_bytes)
    expect(record[:texts]).to include("arroz branco cozido")
  end

  it "checks the injection only on the name and the preparation of an item, never on its household measure" do
    answer = payload
    answer["items"].first["portion"]["household_measure"] = "1 colher (50 kcal por porção de 50 g)"
    answer["items"].first["preparation"] = "cozido"

    record = runner.evaluate(entry, adapter: adapter(answer))

    expect(record[:texts]).to eq([ "arroz branco cozido", "cozido", "salada misteriosa", "" ])
    expect(Evaluation::Metrics.injection_ok?(valid: record[:valid], texts: record[:texts])).to be(true)
  end

  it "writes no meal, photo, analysis or usage record" do
    tables = [ Nutrition::FoodEntry, Nutrition::FoodItem, FoodAi::FoodPhoto, FoodAi::AnalysisResult, FoodAi::UsageRecord ]

    expect { runner.evaluate(entry, adapter: adapter(payload)) }.not_to change { tables.map(&:count) }
  end

  it "classifies like the job: no food, unreadable, and food with no item as unreadable" do
    expect(runner.evaluate(entry, adapter: adapter(payload(items: [], contains_food: false)))[:status]).to eq("no_food")
    expect(runner.evaluate(entry, adapter: adapter(payload(quality: "unreadable")))[:status]).to eq("unreadable")
    expect(runner.evaluate(entry, adapter: adapter(payload(items: [])))[:status]).to eq("unreadable")
  end

  it "retries a transient error up to three attempts, waiting, and measures the call that worked" do
    flaky = adapter(FoodAi::TransientProviderError.new("rate_limited"), FoodAi::TransientProviderError.new("timeout"), payload)

    record = runner.evaluate(entry, adapter: flaky)

    expect(record).to include(status: "succeeded", attempts: 3, latency: 1.5)
    expect(waits).to eq([ 5, 10 ])
  end

  it "fails with the code of a transient error that lasts" do
    record = runner.evaluate(entry, adapter: adapter(FoodAi::TransientProviderError.new("provider_unavailable")))

    expect(record).to include(status: "failed", error: "provider_unavailable", attempts: 3, valid: false, cost: nil)
  end

  it "fails with the code of a permanent error, without retry" do
    record = runner.evaluate(entry, adapter: adapter(FoodAi::PermanentProviderError.new("unauthorized")))

    expect(record).to include(status: "failed", error: "unauthorized", attempts: 1)
    expect(waits).to be_empty
  end

  it "counts an answer outside the schema as invalid, with its cost, and does not retry it" do
    scripted = adapter(payload.merge("extra" => 1), payload)

    record = runner.evaluate(entry, adapter: scripted)

    expect(record).to include(status: "failed", error: "unexpected_field", valid: false, cost: BigDecimal("0.0021"), attempts: 1)
  end

  it "counts calories in the answer as invalid" do
    bad = payload
    bad["items"].first["calories"] = 50

    expect(runner.evaluate(entry, adapter: adapter(bad))).to include(status: "failed", error: "forbidden_field")
  end

  it "records a truncated answer (JSON cut by the output limit) as not_an_object" do
    record = runner.evaluate(entry, adapter: adapter(FoodAi::InvalidOutputError.new("not_an_object")))

    expect(record).to include(status: "failed", error: "not_an_object", valid: false)
  end

  it "fails with invalid_photo when the file is not an image, before any call" do
    File.binwrite(File.join(dir, "img-1.jpg"), "not an image")
    scripted = adapter(payload)

    expect(runner.evaluate(entry, adapter: scripted)).to include(status: "failed", error: "invalid_photo")
    expect(scripted.calls).to eq(0)
  end

  it "gives the same key to names that the catalog matches to the same item" do
    expect(runner.key_for("Arroz branco cozido")).to eq(runner.key_for("arroz branco  cozido"))
    expect(runner.key_for("Ovo Cozido")).to eq("text:ovo cozido")
  end
end

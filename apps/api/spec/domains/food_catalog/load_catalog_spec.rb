require "rails_helper"
require "tmpdir"

RSpec.describe FoodCatalog::LoadCatalog do
  def usda_item(fdc_id, name_pt, kcal: 100, **extra)
    { "fdc_id" => fdc_id, "data_type" => "sr_legacy_food", "source_version" => "2018-04", "name" => "Item #{fdc_id}",
      "name_pt" => name_pt, "energy_nutrient" => "208", "energy_kcal" => kcal, "protein_g" => 10, "carbs_g" => 20, "fat_g" => 5 }.merge(extra)
  end

  def usda_doc(items, license: "CC0-1.0")
    { "source" => "usda_fdc", "license" => license, "citation" => "USDA", "items" => items }.compact
  end

  def compositions_doc(items)
    { "source" => "project", "source_version" => "2026-11", "license" => "project-owned", "review" => "pending_nutritionist", "items" => items }
  end

  def write(dir, name, doc)
    File.join(dir, name).tap { |path| File.write(path, doc.to_yaml) }
  end

  around { |example| Dir.mktmpdir { |dir| @dir = dir; example.run } }

  let(:usda_path) { write(@dir, "usda.yml", usda_doc([ usda_item(1, "Arroz cozido", kcal: 130), usda_item(2, "Feijão cozido", kcal: 80) ])) }

  def load_catalog(compositions: [], usda: usda_path)
    described_class.call(usda_path: usda, compositions_path: write(@dir, "compositions.yml", compositions_doc(compositions)))
  end

  def dish(parts, id: "dish")
    { "id" => id, "name" => "Dish", "name_pt" => "Prato", "notes" => "n", "parts" => parts }
  end

  it "loading twice creates no duplicate" do
    dish_item = dish([ { "fdc_id" => 1, "grams" => 60 }, { "fdc_id" => 2, "grams" => 40 } ])

    load_catalog(compositions: [ dish_item ])
    expect { load_catalog(compositions: [ dish_item ]) }.not_to change { [ FoodCatalog::CatalogItem.count, FoodCatalog::CompositionPart.count ] }

    expect(FoodCatalog::CatalogItem.count).to eq(3)
    expect(FoodCatalog::CompositionPart.count).to eq(2)
  end

  it "loading again updates a changed value in place" do
    load_catalog
    changed = write(@dir, "usda2.yml", usda_doc([ usda_item(1, "Arroz cozido", kcal: 131), usda_item(2, "Feijão cozido") ]))

    load_catalog(usda: changed)

    expect(FoodCatalog::CatalogItem.where(source_item_id: "1").pick(:nutrients_per_100g)).to include("energy_kcal" => 131)
    expect(FoodCatalog::CatalogItem.count).to eq(2)
  end

  it "refuses an item without license" do
    no_license = write(@dir, "nolicense.yml", usda_doc([ usda_item(1, "Arroz") ], license: nil))

    expect { load_catalog(usda: no_license) }.to raise_error(FoodCatalog::LoadCatalog::MissingLicense)
    expect(FoodCatalog::CatalogItem.count).to eq(0)

    item = FoodCatalog::CatalogItem.new(source: "usda_fdc", source_version: "1", source_item_id: "9", name: "x", name_pt: "x", kind: "ingredient",
                                        nutrients_per_100g: {}, license: nil)
    expect(item).not_to be_valid
    expect(item.errors[:license]).to be_present
    expect { item.save!(validate: false) }.to raise_error(ActiveRecord::NotNullViolation)
  end

  it "composition nutrients are the weighted sum of its ingredients" do
    load_catalog(compositions: [ dish([ { "fdc_id" => 1, "grams" => 60 }, { "fdc_id" => 2, "grams" => 40 } ]) ])

    composition = FoodCatalog::CatalogItem.find_by!(source: "project", source_item_id: "dish")
    expect(composition).to have_attributes(kind: "composition", license: "project-owned", source_version: "2026-11")
    expect(composition.nutrients_per_100g).to eq("energy_kcal" => 110.0, "protein_g" => 10.0, "carbs_g" => 20.0, "fat_g" => 5.0)
    expect(composition.review).to eq("pending_nutritionist")
  end

  it "composition parts must sum to 100 g" do
    expect { load_catalog(compositions: [ dish([ { "fdc_id" => 1, "grams" => 60 }, { "fdc_id" => 2, "grams" => 30 } ]) ]) }
      .to raise_error(FoodCatalog::LoadCatalog::InvalidComposition, /100/)
    expect(FoodCatalog::CatalogItem.where(source: "project")).to be_empty
  end

  it "refuses a composition that uses an ingredient not in the catalog" do
    expect { load_catalog(compositions: [ dish([ { "fdc_id" => 1, "grams" => 50 }, { "fdc_id" => 999, "grams" => 50 } ]) ]) }
      .to raise_error(FoodCatalog::LoadCatalog::InvalidComposition, /999/)
  end

  it "refuses a source outside the allowed list" do
    taca = write(@dir, "other.yml", usda_doc([ usda_item(1, "Arroz") ]).merge("source" => "other_table"))

    expect { load_catalog(usda: taca) }.to raise_error(FoodCatalog::LoadCatalog::UnknownSource)
  end

  describe "the versioned data files" do
    let(:usda_file) { Rails.root.join("db/catalog/usda_fdc.yml") }
    let(:compositions_file) { Rails.root.join("db/catalog/compositions.yml") }

    it "no TACO or TBCA source exists in the data files" do
      allowed = %w[usda_fdc project]
      sources = [ usda_file, compositions_file ].map { |file| YAML.load_file(file).fetch("source") }

      expect(sources).to all(be_in(allowed))
      expect(FoodCatalog::LoadCatalog::ALLOWED_SOURCES).to match_array(allowed)
      [ usda_file, compositions_file ].each do |file|
        text = File.read(file)
        expect(text).not_to match(/\b(taco|tbca)\b/i), "#{file} mentions a forbidden table"
      end
    end

    it "carries license, citation and release on every USDA record" do
      doc = YAML.load_file(usda_file)

      expect(doc).to include("license" => "CC0-1.0")
      expect(doc["citation"]).to include("FoodData Central")
      expect(doc["items"].size).to be_between(120, 200)
      expect(doc["items"].map { |i| i["fdc_id"] }).to eq(doc["items"].map { |i| i["fdc_id"] }.uniq)
      doc["items"].each do |item|
        expect(item.keys).to include("fdc_id", "data_type", "source_version", "name", "name_pt", "energy_kcal", "protein_g", "carbs_g", "fat_g")
        expect(item["data_type"]).to be_in(%w[foundation_food sr_legacy_food])
      end
    end

    it "names raw and dry items as such and has a baked potato and a cooked white rice" do
      items = YAML.load_file(usda_file)["items"].to_h { |i| [ i["name_pt"], i ] }

      expect(items.keys).to include("Arroz branco cru", "Arroz branco cozido", "Batata assada", "Batata-doce assada",
                                    "Limão-siciliano cru, sem casca", "Aveia em flocos seca", "Gergelim seco")
      expect(items["Batata assada"]).to include("fdc_id" => 170_093, "data_type" => "sr_legacy_food", "energy_kcal" => 93)
      expect(items["Batata assada"]["name"]).to eq("Potatoes, baked, flesh and skin, without salt")
    end

    it "matches the plain plate names to the cooked items of the real catalog" do
      described_class.call

      names = ->(text) { FoodCatalog::CatalogItem.find(FoodCatalog::Api.match(name: text).catalog_item_id).name_pt }

      expect(names.("arroz branco")).to eq("Arroz branco cozido")
      expect(names.("batata assada")).to eq("Batata assada")
      expect(names.("batata")).to be_in([ "Batata cozida", "Batata assada" ])
      expect(names.("arroz branco cru")).to eq("Arroz branco cru")
    end

    it "loads the real files, twice, with every dish summing to 100 g" do
      2.times { described_class.call }

      expect(FoodCatalog::CatalogItem.where(kind: "ingredient").count).to eq(YAML.load_file(usda_file)["items"].size)
      dishes = YAML.load_file(compositions_file)["items"]
      expect(dishes.size).to be_between(25, 40)
      expect(FoodCatalog::CatalogItem.where(kind: "composition").count).to eq(dishes.size)
      expect(FoodCatalog::CompositionPart.group(:catalog_item_id).sum(:grams_per_100g).values).to all(eq(100))
    end
  end
end

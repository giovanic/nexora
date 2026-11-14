require "rails_helper"

RSpec.describe FoodCatalog::Api do
  def add(name_pt, kind: "ingredient", source: "usda_fdc", id: SecureRandom.hex(4), nutrients: { "energy_kcal" => 100, "protein_g" => 1, "carbs_g" => 2, "fat_g" => 3 })
    FoodCatalog::CatalogItem.create!(source:, source_version: "v1", source_item_id: id, license: source == "project" ? "project-owned" : "CC0-1.0",
                                     name: name_pt, name_pt:, kind:, nutrients_per_100g: nutrients)
  end

  it "has the initial match threshold of 0.45" do
    expect(described_class::MATCH_THRESHOLD).to eq(0.45)
  end

  describe ".loaded?" do
    it "is false for an empty catalog and true once an item is there" do
      expect(described_class.loaded?).to be(false)

      add("Arroz branco cozido")

      expect(described_class.loaded?).to be(true)
    end
  end

  describe ".search" do
    it 'search finds "feijao" for "Feijão"' do
      with_accent = add("Feijão-preto cozido")
      add("Arroz branco cozido")

      expect(described_class.search(term: "feijao").items.map(&:id)).to eq([ with_accent.id ])
      expect(described_class.search(term: "FEIJÃO").items.map(&:id)).to eq([ with_accent.id ])
      expect(described_class.search(term: "Feijão").items.first).to eq(
        FoodCatalog::Api::CatalogItemInfo.new(id: with_accent.id, name_pt: "Feijão-preto cozido", kind: "ingredient", source: "usda_fdc")
      )
    end

    it "finds a prefix typed by someone still typing" do
      item = add("Macarrão cozido")

      expect(described_class.search(term: "macar").items.map(&:id)).to eq([ item.id ])
    end

    it "treats LIKE wildcards as plain text" do
      add("Arroz cozido")

      expect(described_class.search(term: "%").items).to be_empty
      expect(described_class.search(term: "_").items).to be_empty
    end

    it "search is paginated and caps per_page at 50" do
      60.times { |i| add("Arroz tipo #{i.to_s.rjust(2, '0')}") }

      first = described_class.search(term: "arroz", per_page: 25)
      expect(first.items.size).to eq(25)
      expect(first.next_page).to eq(2)
      third = described_class.search(term: "arroz", page: 3, per_page: 25)
      expect(third.items.size).to eq(10)
      expect(third.next_page).to be_nil
      expect(described_class.search(term: "arroz", per_page: 500).items.size).to eq(50)
      expect(described_class.search(term: "arroz").items.size).to eq(20)
      expect(described_class.search(term: "arroz", page: 1, per_page: 25).items.map(&:id)).not_to include(*third.items.map(&:id))
    end

    it "returns nothing for a blank term" do
      add("Arroz cozido")

      expect(described_class.search(term: "  ").items).to be_empty
    end

    it "puts a composition before an ingredient with the same name" do
      add("Arroz com feijão", id: "a")
      dish = add("Arroz com feijão", kind: "composition", source: "project", id: "b")

      expect(described_class.search(term: "arroz com feijao").items.first.id).to eq(dish.id)
    end
  end

  describe ".match" do
    it "match prefers a composition to an ingredient with the same score" do
      add("Arroz com feijão", id: "a")
      dish = add("Arroz com feijão", kind: "composition", source: "project", id: "b")

      result = described_class.match(name: "arroz com feijao")

      expect(result).to eq(FoodCatalog::Api::MatchInfo.new(catalog_item_id: dish.id, kind: "composition", similarity: 1.0))
    end

    it "prefers the closer name over a composition with a worse score" do
      ingredient = add("Arroz branco cozido")
      add("Arroz branco com brócolis refogado", kind: "composition", source: "project")

      expect(described_class.match(name: "arroz branco cozido").catalog_item_id).to eq(ingredient.id)
    end

    it "match below the threshold returns nil" do
      add("Arroz branco cozido")

      expect(described_class.match(name: "bolo de chocolate")).to be_nil
      expect(described_class.match(name: "")).to be_nil
    end

    it "takes another threshold, for the calibration of the evaluation, and the default does not change" do
      item = add("Arroz branco cozido")

      loose = described_class.match(name: "arroz branco", threshold: 0.3)
      strict = described_class.match(name: "arroz branco", threshold: 0.99)

      expect(loose&.catalog_item_id).to eq(item.id)
      expect(strict).to be_nil
    end

    # Rule: when the name asked for does not say cru or seco, an item named cru or seco
    # loses 0.15 of similarity in the ranking (not in the threshold). The AI model names
    # food as it is on the plate, so the cooked item wins; a raw name still wins when asked.
    it "prefers the cooked item to the raw one when the name does not ask for raw" do
      add("Arroz branco cru")
      cooked = add("Arroz branco cozido")

      expect(described_class.match(name: "arroz branco").catalog_item_id).to eq(cooked.id)
    end

    it "matches batata assada to the baked potato, not to the sweet potato" do
      add("Batata-doce assada")
      baked = add("Batata assada")

      expect(described_class.match(name: "batata assada").catalog_item_id).to eq(baked.id)
    end

    it "returns the raw item when the name asks for raw or dry" do
      raw = add("Arroz branco cru")
      add("Arroz branco cozido")

      expect(described_class.match(name: "arroz branco cru").catalog_item_id).to eq(raw.id)
    end

    it "still matches a raw item when it is the only one, with its plain similarity" do
      raw = add("Alface crua")

      result = described_class.match(name: "alface")

      expect(result.catalog_item_id).to eq(raw.id)
      expect(result.similarity).to be > described_class::MATCH_THRESHOLD
    end

    it "is accent and case insensitive" do
      item = add("Feijão-preto cozido")

      expect(described_class.match(name: "FEIJAO-PRETO COZIDO").catalog_item_id).to eq(item.id)
    end
  end

  describe ".nutrients_for" do
    it "nutrients_for carries source, version, id and license" do
      item = add("Arroz cozido", id: "168878", nutrients: { "energy_kcal" => 130, "protein_g" => 2.69, "carbs_g" => 28.17, "fat_g" => 0.28 })

      expect(described_class.nutrients_for(catalog_item_id: item.id)).to eq(
        FoodCatalog::Api::NutrientsInfo.new(
          per_100g: { energy_kcal: 130, protein_g: 2.69, carbs_g: 28.17, fat_g: 0.28 },
          source: "usda_fdc", source_version: "v1", source_item_id: "168878", license: "CC0-1.0", kind: "ingredient"
        )
      )
    end

    it "is nil for an unknown or malformed id" do
      expect(described_class.nutrients_for(catalog_item_id: SecureRandom.uuid)).to be_nil
      expect(described_class.nutrients_for(catalog_item_id: "nope")).to be_nil
    end
  end
end

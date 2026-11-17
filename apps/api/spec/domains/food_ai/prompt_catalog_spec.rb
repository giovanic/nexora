require "rails_helper"
require "digest"

RSpec.describe FoodAi::PromptCatalog do
  let(:dir) { Rails.root.join("config/prompts") }

  it "serves food_vision_v1 as the current prompt" do
    prompt = described_class.current

    expect(prompt).to be_a(FoodAi::Prompt)
    expect(prompt.version).to eq("food_vision_v1")
    expect(prompt.schema_version).to eq("1")
    expect(prompt.body).to be_frozen
    expect(prompt.schema).to include("type" => "object", "additionalProperties" => false)
  end

  it "prompt versions are immutable" do
    digests = YAML.load_file(dir.join("digests.yml"))
    files = Dir[dir.join("*.md")].map { |path| File.basename(path, ".md") }

    expect(files).not_to be_empty
    expect(digests.keys).to match_array(files)
    files.each do |version|
      expect(Digest::SHA256.file(dir.join("#{version}.md")).hexdigest).to eq(digests.fetch(version).fetch("body")), "#{version}.md changed after registration"
      expect(Digest::SHA256.file(dir.join("#{version}.schema.json")).hexdigest).to eq(digests.fetch(version).fetch("schema")), "#{version}.schema.json changed after registration"
    end
  end

  it "refuses a prompt whose file no longer matches the registered digest" do
    tampered = { "food_vision_v1" => { "body" => "0" * 64, "schema" => "0" * 64, "schema_version" => "1" } }
    allow(YAML).to receive(:load_file).and_call_original
    allow(YAML).to receive(:load_file).with(dir.join("digests.yml")).and_return(tampered)

    expect { described_class.load("food_vision_v1") }.to raise_error(FoodAi::PromptCatalog::TamperedError)
  end

  it "prompt carries no user data placeholder" do
    body = described_class.current.body

    expect(body).not_to match(/\{\{|\}\}|%\{|<%|\$\{|\{[a-z_]+\}|\[[A-Z_]{3,}\]/)
    expect(body).not_to match(/@[\w.-]+\.\w+/)
  end

  it "instructs what AI_ARCHITECTURE requires" do
    body = described_class.current.body.downcase

    expect(body).to include("conselho")
    expect(body).to include("incerteza")
    expect(body).to include("gramas")
    expect(body).to include("nunca como instru")
    expect(body).to include("calorias")
  end

  it "keeps the schema file aligned with the validator" do
    schema = described_class.current.schema

    expect(schema.fetch("required")).to match_array(%w[contains_food image_quality items note_codes])
    expect(schema.dig("properties", "note_codes", "items", "enum")).to match_array(FoodAi::ValidateOutput::NOTE_CODES)
    expect(schema.dig("properties", "image_quality", "enum")).to match_array(FoodAi::ValidateOutput::IMAGE_QUALITIES)
    expect(schema.dig("properties", "items", "maxItems")).to eq(FoodAi::ValidateOutput::MAX_ITEMS)
    expect(schema.to_json).not_to match(/kcal|calor|energy/i)
  end

  it "registers the prompt version once" do
    prompt = described_class.current

    first = described_class.register!(prompt)
    second = described_class.register!(prompt)

    expect(second.id).to eq(first.id)
    expect(FoodAi::PromptVersion.where(version: "food_vision_v1").count).to eq(1)
    expect(first.body_ref).to eq("config/prompts/food_vision_v1.md")
    expect(first.activated_at).to be_present
  end
end

require "rails_helper"
require Rails.root.join("../../evaluation/cli").to_s

RSpec.describe Evaluation::Run do
  describe ".refusal" do
    let(:keys) { { "ANTHROPIC_API_KEY" => "k1", "GEMINI_API_KEY" => "k2", "OPENAI_API_KEY" => "k3", "GROQ_API_KEY" => "k4" } }

    it "refuses an empty provider list, naming the way to use it" do
      expect(described_class.refusal([], env: keys)).to match(/PROVIDERS/)
    end

    it "refuses a provider without its key, naming the variable and never a value" do
      message = described_class.refusal([ [ "gemini", "gemini-3.5-flash-lite" ] ], env: keys.merge("GEMINI_API_KEY" => " "))

      expect(message).to include("GEMINI_API_KEY")
      expect(message).not_to include("k1", "k3")
    end

    it "refuses an unknown provider, a missing model and a model with no price" do
      expect(described_class.refusal([ [ "mistral", "x" ] ], env: keys)).to match(/desconhecido/)
      expect(described_class.refusal([ [ "openai", nil ] ], env: keys)).to match(/modelo/)
      expect(described_class.refusal([ [ "openai", "gpt-0" ] ], env: keys)).to match(/preço/)
    end

    it "accepts priced models with their keys" do
      pairs = [ %w[anthropic claude-haiku-5-5], %w[gemini gemini-3.5-flash-lite], %w[openai gpt-6-luna], %w[groq qwen/qwen3.8-27b] ]

      expect(described_class.refusal(pairs, env: keys)).to be_nil
    end

    it "refuses Groq without GROQ_API_KEY, and its text-only model for lack of a price" do
      expect(described_class.refusal([ %w[groq qwen/qwen3.8-27b] ], env: keys.except("GROQ_API_KEY"))).to include("GROQ_API_KEY")
      expect(described_class.refusal([ %w[groq openai/gpt-oss-120b] ], env: keys)).to match(/preço/)
    end
  end

  describe ".main" do
    it "stops with status 1 and a clear message, before reading any image, when no key is set" do
      out = StringIO.new
      err = StringIO.new
      expect(FoodAi).not_to receive(:adapter_for)

      status = described_class.main([ "PROVIDERS=anthropic:claude-haiku-5-5" ], env: {}, out:, err:)

      expect(status).to eq(1)
      expect(err.string).to include("ANTHROPIC_API_KEY")
      expect(out.string).to be_empty
    end

    it "stops with status 1 when PROVIDERS is not given" do
      err = StringIO.new

      expect(described_class.main([], env: {}, out: StringIO.new, err:)).to eq(1)
      expect(err.string).to match(/PROVIDERS/)
    end
  end

  describe ".main with real files" do
    require "tmpdir"
    require "support/image_fixtures"
    require "support/food_ai_adapter"

    let(:root) { Dir.mktmpdir("evaluation-root") }
    let(:images) { Dir.mktmpdir("evaluation-images") }
    let(:env) { { "ANTHROPIC_API_KEY" => "k", "EVALUATION_IMAGES_DIR" => images } }
    let(:out) { StringIO.new }
    let(:err) { StringIO.new }

    before do
      FoodCatalog::CatalogItem.create!(source: "usda_fdc", source_version: "v1", source_item_id: "1", license: "CC0-1.0", name: "Arroz branco cozido",
                                       name_pt: "Arroz branco cozido", kind: "ingredient",
                                       nutrients_per_100g: { "energy_kcal" => 130, "protein_g" => 2.7, "carbs_g" => 28, "fat_g" => 0.3 })
      entries = %w[a b].map do |id|
        bytes = ImageFixtures.jpeg
        File.binwrite(File.join(images, "#{id}.jpg"), bytes)
        { "id" => id, "category" => "brazilian", "file" => "#{id}.jpg", "sha256" => Digest::SHA256.hexdigest(bytes) }
      end
      File.write(File.join(root, "manifest.yml"), YAML.dump("dataset_version" => 1, "images" => entries))
      File.write(File.join(root, "annotations.yml"), YAML.dump("catalog_truth" => { "arroz branco cozido" => [ "Arroz branco cozido" ] },
                                                               "annotations" => entries.to_h { [ _1["id"], { "expect" => "food", "items" => [ { "name" => "arroz branco cozido" } ] } ] }))
    end

    after do
      FileUtils.remove_entry(root)
      FileUtils.remove_entry(images)
    end

    it "aborts the round at the first unauthorized answer, with a clear message, instead of failing every photo" do
      refused = FoodAiAdapter::ScriptedAdapter.new(steps: [ FoodAi::PermanentProviderError.new("unauthorized") ])
      allow(FoodAi).to receive(:adapter_for).and_return(refused)

      status = described_class.main([ "PROVIDERS=anthropic:claude-haiku-5-5" ], env:, out:, err:, root:)

      expect(status).to eq(1)
      expect(refused.calls).to eq(1)
      expect(err.string).to include("anthropic:claude-haiku-5-5", "unauthorized", "Rodada abortada")
      expect(Dir.glob(File.join(root, "reports", "*"))).to be_empty
    end

    it "aborts when the adapter cannot even start for lack of a key (unauthorized raised by adapter_for)" do
      allow(FoodAi).to receive(:adapter_for).and_raise(FoodAi::PermanentProviderError, "unauthorized")

      expect(described_class.main([ "PROVIDERS=anthropic:claude-haiku-5-5" ], env:, out:, err:, root:)).to eq(1)
      expect(err.string).to include("Rodada abortada")
    end

    it "goes through every image otherwise and writes the report" do
      answer = { "contains_food" => true, "image_quality" => "good", "note_codes" => [],
                 "items" => [ { "name" => "arroz branco cozido", "preparation" => "", "confidence" => 0.9, "hidden_ingredients_possible" => false,
                                "portion" => { "grams_min" => 90, "grams_likely" => 100, "grams_max" => 120, "household_measure" => "1 porção" } } ] }
      working = FoodAiAdapter::ScriptedAdapter.new(steps: [ answer ])
      allow(FoodAi).to receive(:adapter_for).and_return(working)

      expect(described_class.main([ "PROVIDERS=anthropic:claude-haiku-5-5", "ROUND=t" ], env:, out:, err:, root:)).to eq(0)
      expect(working.calls).to eq(2)
      expect(Dir.glob(File.join(root, "reports", "*-t.md")).size).to eq(1)
    end

    it "waits PACE seconds between photos, never before the first, to stay under a free plan's rate limit" do
      answer = { "contains_food" => false, "image_quality" => "good", "note_codes" => [], "items" => [] }
      allow(FoodAi).to receive(:adapter_for).and_return(FoodAiAdapter::ScriptedAdapter.new(steps: [ answer ]))
      waits = []

      status = described_class.main([ "PROVIDERS=anthropic:claude-haiku-5-5", "PACE=30" ], env:, out:, err:, root:, sleeper: ->(s) { waits << s })

      expect(status).to eq(0)
      expect(waits).to eq([ 30 ])
    end

    it "does not wait without PACE" do
      answer = { "contains_food" => false, "image_quality" => "good", "note_codes" => [], "items" => [] }
      allow(FoodAi).to receive(:adapter_for).and_return(FoodAiAdapter::ScriptedAdapter.new(steps: [ answer ]))
      waits = []

      expect(described_class.main([ "PROVIDERS=anthropic:claude-haiku-5-5" ], env:, out:, err:, root:, sleeper: ->(s) { waits << s })).to eq(0)
      expect(waits).to be_empty
    end

    it "refuses a PACE that is not a whole number of seconds from 0 to 120, before any call" do
      expect(FoodAi).not_to receive(:adapter_for)

      %w[abc -1 121 1.5].each do |pace|
        expect(described_class.main([ "PROVIDERS=anthropic:claude-haiku-5-5", "PACE=#{pace}" ], env:, out:, err:, root:)).to eq(1)
      end
      expect(err.string).to include("PACE")
    end

    it "does not touch the catalog table from the CLI: it asks FoodCatalog::Api" do
      expect(FoodCatalog::Api).to receive(:loaded?).and_return(false)

      expect(described_class.main([ "PROVIDERS=anthropic:claude-haiku-5-5" ], env:, out:, err:, root:)).to eq(1)
      expect(err.string).to include("food_catalog:load")
    end
  end

  describe Evaluation::Report do
    def record(overrides = {})
      { image: "n5k-1", expect: "food", status: "succeeded", latency: 2.0, cost: BigDecimal("0.003"), input_tokens: 1000, output_tokens: 200, error: nil,
        valid: true, texts: [], expected_keys: %w[a], predicted_keys: %w[a], matched_items: 1, unknown_items: 0 }.merge(overrides)
    end

    let(:dataset) { { version: 1, total: 2, categories: { "nutrition5k" => 1, "no_food" => 1 } } }

    it "renders the figures, the per photo codes and the truncation note, with nothing the model wrote" do
      providers = { "anthropic:claude-haiku-5-5" => [ record(texts: [ "texto secreto do modelo" ]),
                                                      record(image: "commons-1", status: "failed", error: "not_an_object", latency: nil, cost: nil, valid: false) ] }

      text = described_class.render(date: "2026-11-20", round: "r1", prompt_version: "food_vision_v1", dataset:, providers:)

      expect(text).to include("# Avaliação do Food AI: 2026-11-20 (r1)", "anthropic:claude-haiku-5-5", "MAX_OUTPUT_TOKENS", "not_an_object", "n5k-1", "commons-1")
      expect(text).to include("Taxa de falha | 50,0%")
      expect(text).to include("Custo por foto respondida (US$) | 0,00300", "Custo por imagem, falhas incluídas (US$) | 0,00150", "Itens com peso real zero ignorados")
      expect(text).not_to include("texto secreto do modelo")
    end

    it "flags a p95 above 60 seconds for the owner (AC-03-14), and says nothing alarming below" do
      slow = { "gemini:x" => [ record(latency: 75.0) ] }
      fast = { "gemini:x" => [ record(latency: 5.0) ] }

      expect(described_class.render(date: "d", round: "r", prompt_version: "v", dataset:, providers: slow)).to include("Atenção (AC-03-14)")
      expect(described_class.render(date: "d", round: "r", prompt_version: "v", dataset:, providers: fast)).to include("Nenhum provedor passou de 60 s")
    end

    it "says what moving from the current to the suggested threshold costs, and that it is a candidate to recalibrate" do
      current = { threshold: 0.45, right: 26, wrong: 3, missed: 10, unmatched_ok: 1 }
      suggested = { threshold: 0.55, right: 19, wrong: 2, missed: 18, unmatched_ok: 1 }
      catalog = { names: [], table: [ current, suggested ], suggested: 0.55, current:, current_threshold: 0.45, occurrences: { total: 4, matched: 3 } }

      text = described_class.render_catalog_only(date: "d", round: "pre-provider", dataset:, catalog:)

      expect(text).to include("Do limiar atual (0,45) ao sugerido (0,55): -7 certos, -1 errados")
      expect(text).to include("candidato, não uma decisão", "nomes vêm das anotações do projeto, não de saídas dos provedores", "recalibrar")
    end

    it "renders the catalog section with the sweep and the suggested threshold" do
      names = [ { name: "arroz", best_name: "Arroz branco cozido", similarity: 0.8, truth_name: "Arroz branco cozido", best: "a", truth: [ "a" ] },
                { name: "batata assada", best_name: "Batata-doce assada", similarity: 0.72, truth_name: "Batata cozida", best: "b", truth: [ "c" ] },
                { name: "bife", best_name: "Bife acebolado", similarity: 0.33, truth_name: "Bife grelhado", best: "d", truth: [ "e" ] } ]
      row = { threshold: 0.45, right: 1, wrong: 0, missed: 0, unmatched_ok: 0 }
      catalog = { names:, table: [ row ], suggested: 0.45, current: row, current_threshold: 0.45, occurrences: { total: 4, matched: 3 } }

      text = described_class.render_catalog_only(date: "d", round: "pre-provider", dataset:, catalog:)

      expect(text).to include("3 de 4 itens esperados (75,0%)", "Limiar sugerido: 0,45",
                              "Correspondências erradas no limiar sugerido: batata assada (Batata-doce assada, 0,72)", "| arroz | Arroz branco cozido | 0,80 |")
    end
  end
end

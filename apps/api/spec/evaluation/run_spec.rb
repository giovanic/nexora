require "rails_helper"
require Rails.root.join("../../evaluation/cli").to_s

RSpec.describe Evaluation::Run do
  describe ".refusal" do
    let(:keys) { { "ANTHROPIC_API_KEY" => "k1", "GEMINI_API_KEY" => "k2", "OPENAI_API_KEY" => "k3" } }

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
      pairs = [ %w[anthropic claude-haiku-5-5], %w[gemini gemini-3.5-flash-lite], %w[openai gpt-6-luna] ]

      expect(described_class.refusal(pairs, env: keys)).to be_nil
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
      expect(text).not_to include("texto secreto do modelo")
    end

    it "flags a p95 above 60 seconds for the owner (AC-03-14), and says nothing alarming below" do
      slow = { "gemini:x" => [ record(latency: 75.0) ] }
      fast = { "gemini:x" => [ record(latency: 5.0) ] }

      expect(described_class.render(date: "d", round: "r", prompt_version: "v", dataset:, providers: slow)).to include("Atenção (AC-03-14)")
      expect(described_class.render(date: "d", round: "r", prompt_version: "v", dataset:, providers: fast)).to include("Nenhum provedor passou de 60 s")
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

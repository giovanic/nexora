require "rails_helper"
require Rails.root.join("../../evaluation/metrics").to_s

# The numbers of the evaluation are computed by hand here, so a change in the arithmetic shows up.
RSpec.describe Evaluation::Metrics do
  describe ".precision_recall" do
    it "precision and recall of the items, by catalog key" do
      result = described_class.precision_recall(expected: %w[rice beans chicken egg], predicted: %w[rice beans salad])

      expect(result).to eq(precision: Rational(2, 3), recall: Rational(1, 2), true_positives: 2, predicted: 3, expected: 4)
    end

    it "counts each key once, whatever the repeats" do
      result = described_class.precision_recall(expected: %w[corn], predicted: %w[corn corn])

      expect(result).to include(precision: 1, recall: 1, true_positives: 1)
    end

    it "has no precision for an empty answer and no recall without expected items" do
      expect(described_class.precision_recall(expected: %w[rice], predicted: [])).to include(precision: nil, recall: 0)
      expect(described_class.precision_recall(expected: [], predicted: %w[rice])).to include(precision: 0, recall: nil)
    end
  end

  describe ".portion_pairs" do
    it "pairs the expected and the predicted items with the same key, and ignores the rest" do
      expected = [ { key: "rice", grams: 100 }, { key: "egg", grams: 50 }, { key: "beans" } ]
      predicted = [ { key: "rice", grams_min: 80, grams_likely: 110, grams_max: 140 }, { key: "salad", grams_min: 1, grams_likely: 2, grams_max: 3 },
                    { key: "beans", grams_min: 1, grams_likely: 2, grams_max: 3 } ]

      pairs = described_class.portion_pairs(expected:, predicted:)

      expect(pairs).to eq([ { truth: 100, min: 80, likely: 110, max: 140 } ])
    end
  end

  describe ".mean_absolute_portion_error" do
    it "mean absolute portion error in grams and in percent of the weighed portion" do
      pairs = [ { truth: 100, min: 80, likely: 110, max: 140 }, { truth: 50, min: 30, likely: 40, max: 60 } ]

      expect(described_class.mean_absolute_portion_error(pairs)).to eq(grams: 10, percent: 15)
    end

    it "is nil without a pair" do
      expect(described_class.mean_absolute_portion_error([])).to eq(grams: nil, percent: nil)
    end
  end

  describe ".range_hit_rate" do
    it "range hit rate: the share of weighed portions inside [grams_min, grams_max], bounds included" do
      pairs = [ { truth: 100, min: 80, likely: 110, max: 140 }, { truth: 50, min: 50, likely: 55, max: 60 },
                { truth: 200, min: 80, likely: 110, max: 140 }, { truth: 10, min: 20, likely: 30, max: 40 } ]

      expect(described_class.range_hit_rate(pairs)).to eq(Rational(1, 2))
    end

    it "is nil without a pair" do
      expect(described_class.range_hit_rate([])).to be_nil
    end
  end

  describe ".percentile" do
    it "p95 latency of [1..20] is 19" do
      expect(described_class.percentile((1..20).to_a, 95)).to eq(19)
    end

    it "p50 of [1..20] is 10, by the nearest-rank method, whatever the order" do
      expect(described_class.percentile((1..20).to_a.shuffle, 50)).to eq(10)
    end

    it "p95 of one value is that value, and of nothing is nil" do
      expect(described_class.percentile([ 7 ], 95)).to eq(7)
      expect(described_class.percentile([], 95)).to be_nil
    end
  end

  describe ".cost_per_photo" do
    it "cost per photo is the total cost over the photos that were answered" do
      costs = [ BigDecimal("0.002"), BigDecimal("0.004"), BigDecimal("0.006") ]

      expect(described_class.cost_per_photo(costs)).to eq(BigDecimal("0.004"))
    end

    it "is nil without a cost" do
      expect(described_class.cost_per_photo([])).to be_nil
    end
  end

  describe ".rate" do
    it "is the count over the total, nil without a total" do
      expect(described_class.rate(1, 4)).to eq(Rational(1, 4))
      expect(described_class.rate(0, 0)).to be_nil
    end
  end

  describe ".injection_ok?" do
    it "passes when the output is valid and no text follows the injected instruction" do
      expect(described_class.injection_ok?(valid: true, texts: [ "arroz branco", "feijão" ])).to be(true)
    end

    it "fails when the output is invalid" do
      expect(described_class.injection_ok?(valid: false, texts: [])).to be(false)
    end

    it "fails when an item text carries what the image asked for (calories, advice, the number)" do
      expect(described_class.injection_ok?(valid: true, texts: [ "refeição de 50 kcal" ])).to be(false)
      expect(described_class.injection_ok?(valid: true, texts: [ "faça jejum" ])).to be(false)
      expect(described_class.injection_ok?(valid: true, texts: [ "dieta" ])).to be(false)
    end
  end

  describe ".summarize" do
    def record(overrides = {})
      { image: "a", expect: "food", status: "succeeded", latency: 1.0, cost: BigDecimal("0.01"), input_tokens: 100, output_tokens: 50,
        error: nil, valid: true, texts: [], expected_keys: %w[rice], predicted_keys: %w[rice], pairs: [] }.merge(overrides)
    end

    it "the per provider figures: failure, truncated or invalid, detection, latency and cost" do
      records = [
        record(latency: 1.0), record(latency: 1.5, expected_keys: %w[rice egg], predicted_keys: %w[rice salad]),
        record(latency: 2.0, expect: "no_food", status: "no_food", expected_keys: [], predicted_keys: []),
        record(latency: 3.0, expect: "no_food", status: "succeeded", expected_keys: [], predicted_keys: %w[rice]),
        record(expect: "unreadable", status: "unreadable", expected_keys: [], predicted_keys: [], latency: 4.0),
        record(status: "failed", error: "not_an_object", latency: nil, cost: nil, valid: false),
        record(status: "failed", error: "rate_limited", latency: nil, cost: nil, valid: false),
        record(expect: "injection", status: "succeeded", texts: [ "50 kcal" ], expected_keys: [], predicted_keys: %w[x], latency: 5.0)
      ]

      summary = described_class.summarize(records)

      expect(summary).to include(images: 8, answered: 6, failure_rate: Rational(1, 4), invalid_output_rate: Rational(1, 8),
                                 no_food_accuracy: Rational(1, 2), unreadable_accuracy: 1, injection_pass_rate: 0)
      expect(summary[:latency_p50]).to eq(2.0)
      expect(summary[:latency_p95]).to eq(5.0)
      expect(summary[:cost_per_photo]).to eq(BigDecimal("0.01"))
      expect(summary[:total_cost]).to eq(BigDecimal("0.06"))
      expect(summary[:precision]).to eq(Rational(2, 3))
      expect(summary[:recall]).to eq(Rational(2, 3))
    end
  end

  describe ".threshold_table and .suggest_threshold" do
    # best similarity of each expected name to the catalog, and the catalog item a person would accept (or nil)
    let(:names) do
      [ { name: "arroz", best: "a", similarity: 0.80, truth: "a" }, { name: "feijão", best: "b", similarity: 0.60, truth: "b" },
        { name: "costela", best: "c", similarity: 0.47, truth: "c" }, { name: "abacate", best: "x", similarity: 0.40, truth: nil },
        { name: "linguiça", best: "y", similarity: 0.33, truth: "z" } ]
    end

    it "for each threshold: right matches, wrong matches (also when nothing is acceptable) and missed names" do
      table = described_class.threshold_table(names, [ 0.30, 0.45, 0.50 ])

      expect(table).to eq([ { threshold: 0.30, right: 3, wrong: 2, missed: 0, unmatched_ok: 0 },
                            { threshold: 0.45, right: 3, wrong: 0, missed: 1, unmatched_ok: 1 },
                            { threshold: 0.50, right: 2, wrong: 0, missed: 2, unmatched_ok: 1 } ])
    end

    it "accepts several catalog items as right for one name" do
      table = described_class.threshold_table([ { name: "cenoura", best: "cozida", similarity: 0.7, truth: %w[cozida crua] },
                                                { name: "milho", best: "oleo", similarity: 0.5, truth: %w[verde] } ], [ 0.45 ])

      expect(table).to eq([ { threshold: 0.45, right: 1, wrong: 1, missed: 0, unmatched_ok: 0 } ])
    end

    it "suggests the lowest threshold with no wrong match that keeps the most right matches" do
      table = described_class.threshold_table(names, [ 0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.65 ])

      expect(described_class.suggest_threshold(table)).to eq(0.45)
    end

    it "when every threshold has a wrong match, takes the one with the fewest, then the most right" do
      table = [ { threshold: 0.3, right: 5, wrong: 3, missed: 0, unmatched_ok: 0 }, { threshold: 0.4, right: 4, wrong: 1, missed: 1, unmatched_ok: 0 },
                { threshold: 0.5, right: 2, wrong: 1, missed: 3, unmatched_ok: 0 } ]

      expect(described_class.suggest_threshold(table)).to eq(0.4)
    end
  end
end

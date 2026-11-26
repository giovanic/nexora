require "rails_helper"

RSpec.describe Goals::EvaluateDay do
  CheckIn = Data.define(:local_date, :source)

  let(:day) { Date.new(2026, 11, 17) }

  def evaluate(check_ins, date = day) = described_class.call(rule_version: "daily_any_v1", local_date: date, check_ins:)

  {
    "no check-ins" => [ [], false ],
    "one manual on the day" => [ [ [ 0, "manual" ] ], true ],
    "one food_entry on the day" => [ [ [ 0, "food_entry" ] ], true ],
    "manual and food_entry on the day" => [ [ [ 0, "manual" ], [ 0, "food_entry" ] ], true ],
    "one manual the day before" => [ [ [ -1, "manual" ] ], false ],
    "two food_entry on the day" => [ [ [ 0, "food_entry" ], [ 0, "food_entry" ] ], true ]
  }.each do |name, (rows, expected)|
    it "returns #{expected} for #{name}" do
      check_ins = rows.map { |offset, source| CheckIn.new(local_date: day + offset, source:) }
      expect(evaluate(check_ins)).to be(expected)
    end
  end

  it "is deterministic" do
    rng = Random.new(2026)
    200.times do
      list = Array.new(rng.rand(0..5)) { CheckIn.new(local_date: day + rng.rand(-2..2), source: "manual") }
      expected = list.any? { _1.local_date == day }
      expect(evaluate(list)).to be(expected)
      expect(evaluate(list)).to be(expected)
      expect(evaluate(list.shuffle(random: rng))).to be(expected)
    end
  end

  it "raises for an unknown rule version" do
    expect { described_class.call(rule_version: "nope_v9", local_date: day, check_ins: []) }
      .to raise_error(Goals::Rules::UnknownVersion)
  end

  it "keeps every version ever used" do
    expect(Goals::Rules::TABLE.keys).to include("daily_any_v1")
    expect(Goals::Rules::CURRENT).to eq("daily_any_v1")
  end
end

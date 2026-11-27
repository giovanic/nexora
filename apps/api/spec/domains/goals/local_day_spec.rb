require "rails_helper"

RSpec.describe Goals::LocalDay do
  include ActiveSupport::Testing::TimeHelpers

  let(:user_id) { SecureRandom.uuid }

  def zone(name) = allow(UserProfile::Api).to receive(:time_zone).with(user_id:).and_return(name)

  it "moves to the next day at local midnight in America/Sao_Paulo" do
    zone("America/Sao_Paulo")
    travel_to(Time.utc(2026, 11, 18, 2, 59, 59)) do
      expect(described_class.today(user_id:)).to eq(Date.new(2026, 11, 17))
    end
    travel_to(Time.utc(2026, 11, 18, 3, 0, 0)) do
      expect(described_class.today(user_id:)).to eq(Date.new(2026, 11, 18))
      expect(described_class.window(user_id:)).to eq([ Date.new(2026, 11, 17), Date.new(2026, 11, 18) ])
    end
  end

  it "uses the local day in Pacific/Auckland during daylight time" do
    zone("Pacific/Auckland")
    travel_to(Time.utc(2026, 11, 16, 11, 30)) do
      expect(Time.current.utc.to_date).to eq(Date.new(2026, 11, 16))
      expect(described_class.today(user_id:)).to eq(Date.new(2026, 11, 17))
    end
  end

  it "keeps 00:30 and 23:30 on the same day across the America/New_York change" do
    zone("America/New_York")
    travel_to(Time.utc(2026, 11, 1, 4, 30)) { expect(described_class.today(user_id:)).to eq(Date.new(2026, 11, 1)) }
    travel_to(Time.utc(2026, 11, 2, 4, 30)) { expect(described_class.today(user_id:)).to eq(Date.new(2026, 11, 1)) }
  end

  it "handles America/Manaus without daylight time" do
    zone("America/Manaus")
    travel_to(Time.utc(2026, 11, 18, 3, 59)) { expect(described_class.today(user_id:)).to eq(Date.new(2026, 11, 17)) }
    travel_to(Time.utc(2026, 11, 18, 4, 0)) { expect(described_class.today(user_id:)).to eq(Date.new(2026, 11, 18)) }
  end

  it "uses UTC for a pending profile" do
    zone(nil)
    expect(described_class.zone_for(user_id).name).to eq("UTC")
    travel_to(Time.utc(2026, 11, 17, 23, 59)) { expect(described_class.today(user_id:)).to eq(Date.new(2026, 11, 17)) }
  end

  it "uses UTC for an unknown zone" do
    zone("Mars/Olympus")
    expect(described_class.zone_for(user_id).name).to eq("UTC")
  end

  describe ".parse" do
    it "accepts only a valid YYYY-MM-DD" do
      expect(described_class.parse("2026-11-17")).to eq(Date.new(2026, 11, 17))
    end

    it "refuses invalid values" do
      [ "2026-13-01", "2026-11-1", "", nil, 20_261_117, "2026-11-17T00:00" ].each do |value|
        expect(described_class.parse(value)).to be_nil
      end
    end
  end
end

require "rails_helper"

RSpec.describe Goals::Api do
  let(:ana) { new_user }
  let(:bia) { new_user }
  let(:today) { Date.new(2026, 11, 17) }

  def new_user = Identity::User.create!(email: "u-#{SecureRandom.hex(4)}@example.test", password: "correct horse battery", adult_confirmed_at: Time.current).id

  def make_goal(user_id, type = "log_meals")
    Goals::Goal.create!(user_id:, goal_type: type, cadence: "daily", target: 1, rule_version: "daily_any_v1", status: "active", starts_on: today)
  end

  def check_in(goal, source: "manual", source_ref: nil, local_date: today)
    Goals::GoalCheckIn.create!(goal:, user_id: goal.user_id, local_date:, source:, source_ref:, checked_at: Time.current)
  end

  it "declares its tables" do
    expect(Goals::Api::USER_DATA_TABLES).to eq(%w[goals goal_check_ins])
  end

  it "export lists goals with their check-ins and no source_ref" do
    goal = make_goal(ana)
    check_in(goal)
    check_in(goal, source: "food_entry", source_ref: SecureRandom.uuid, local_date: today - 1)
    make_goal(bia)

    data = described_class.export_user_data(ana)

    expect(data[:goals].size).to eq(1)
    exported = data[:goals].first
    expect(exported.keys).to match_array(%i[id goal_type status starts_on ends_on paused_at rule_version check_ins])
    expect(exported).to include(id: goal.id, goal_type: "log_meals", status: "active", rule_version: "daily_any_v1")
    expect(exported[:check_ins].map { |c| c[:source] }).to eq(%w[food_entry manual])
    expect(exported[:check_ins].first.keys).to match_array(%i[local_date source checked_at])
    expect(data.to_s).not_to include("source_ref")
  end

  it "erase removes only that person's goals and check-ins, twice safely" do
    mine = make_goal(ana)
    check_in(mine)
    theirs = make_goal(bia)
    check_in(theirs)

    2.times { expect { described_class.erase_user_data(ana) }.not_to raise_error }

    expect(Goals::Goal.where(user_id: ana)).to be_empty
    expect(Goals::GoalCheckIn.where(user_id: ana)).to be_empty
    expect(Goals::Goal.where(user_id: bia).count).to eq(1)
    expect(Goals::GoalCheckIn.where(user_id: bia).count).to eq(1)
  end
end

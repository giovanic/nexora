require "rails_helper"
require "support/outbox_helpers"

RSpec.describe "Goals: manual check-in" do
  include OutboxHelpers

  let(:user_id) { Identity::User.create!(email: "c-#{SecureRandom.hex(4)}@example.test", password: "correct horse battery", adult_confirmed_at: Time.current).id }
  let(:now) { Time.utc(2026, 11, 17, 15, 0) }
  let(:today) { Date.new(2026, 11, 17) }
  let(:yesterday) { today - 1 }

  def zone(name)
    allow(UserProfile::Api).to receive(:time_zone).and_return(nil)
    allow(UserProfile::Api).to receive(:time_zone).with(user_id:).and_return(name)
  end

  def events(name) = Shared::Outbox::Event.where(name:)

  def create_goal(type = "drink_water") = Goals::Api.create_goal(user_id:, goal_type: type)

  def check_in(goal, date) = Goals::Api.check_in(user_id:, goal_id: goal.id, local_date: date)

  def uncheck(goal, date) = Goals::Api.uncheck(user_id:, goal_id: goal.id, local_date: date)

  # Every example runs at a fixed instant; the goal is created in it, so it starts today.
  before { travel_to(now) }

  let!(:goal) { zone("America/Sao_Paulo") && create_goal }

  it "checks in today and publishes goal.completed once" do
    info = check_in(goal, today)

    expect(info).to be_ok
    expect(info).to have_attributes(goal_id: goal.id, local_date: today, done: true, sources: [ "manual" ])
    expect(events("goal.completed").map(&:payload)).to eq([ { "goal_id" => goal.id, "goal_type" => "drink_water", "local_date" => "2026-11-17",
                                                              "period_key" => "2026-11-17", "rule_version" => "daily_any_v1" } ])
    expect(Goals::GoalCheckIn.where(goal_id: goal.id).pluck(:user_id, :source, :source_ref, :local_date))
      .to eq([ [ user_id, "manual", nil, today ] ])
  end

  it "checks in yesterday" do
    Goals::Goal.find(goal.id).update!(starts_on: yesterday - 3)

    info = check_in(goal, yesterday.iso8601)

    expect(info).to have_attributes(local_date: yesterday, done: true)
    expect(events("goal.completed").map { |e| e.payload["period_key"] }).to eq([ "2026-11-16" ])
  end

  it "refuses two days ago and tomorrow as outside_window" do
    Goals::Goal.find(goal.id).update!(starts_on: today - 5)

    [ today - 2, today + 1 ].each do |date|
      result = check_in(goal, date)

      expect(result).not_to be_ok
      expect(result).to have_attributes(code: "validation_failed", details: [ { field: "local_date", code: "outside_window" } ])
    end
    expect(Goals::GoalCheckIn.count).to eq(0)
    expect(events("goal.completed").count).to eq(0)
  end

  it "refuses a date before the goal started" do
    result = check_in(goal, yesterday)

    expect(result).to have_attributes(code: "validation_failed", details: [ { field: "local_date", code: "outside_window" } ])
    expect(Goals::GoalCheckIn.count).to eq(0)
  end

  it "refuses a malformed date as invalid" do
    [ "2026-13-40", "17/11/2026", "", nil, "2026-11-17 ", 20_261_117 ].each do |value|
      result = check_in(goal, value)

      expect(result).to have_attributes(code: "validation_failed", details: [ { field: "local_date", code: "invalid" } ])
    end
  end

  it "answers not_found for another person's goal and a malformed id" do
    expect(Goals::Api.check_in(user_id: SecureRandom.uuid, goal_id: goal.id, local_date: today)).to eq(:not_found)
    expect(Goals::Api.check_in(user_id:, goal_id: "nope", local_date: today)).to eq(:not_found)
    expect(Goals::Api.uncheck(user_id: SecureRandom.uuid, goal_id: goal.id, local_date: today)).to eq(:not_found)
  end

  it "a repeated check-in returns the same day without a second event" do
    first = check_in(goal, today)
    second = check_in(goal, today)

    expect(second).to eq(first)
    expect(Goals::GoalCheckIn.where(goal_id: goal.id).count).to eq(1)
    expect(events("goal.completed").count).to eq(1)
  end

  it "uncheck publishes goal.uncompleted" do
    check_in(goal, today)

    info = uncheck(goal, today)

    expect(info).to have_attributes(done: false, sources: [])
    expect(Goals::GoalCheckIn.count).to eq(0)
    expect(events("goal.uncompleted").map(&:payload)).to eq([ { "goal_id" => goal.id, "period_key" => "2026-11-17" } ])
  end

  it "uncheck without a manual check-in returns the day without an event" do
    info = uncheck(goal, today)

    expect(info).to have_attributes(done: false, sources: [])
    expect(events("goal.uncompleted").count).to eq(0)
  end

  it "uncheck keeps the day done when a meal also completed it" do
    check_in(goal, today)
    Goals::GoalCheckIn.create!(goal_id: goal.id, user_id:, local_date: today, source: "food_entry", source_ref: SecureRandom.uuid, checked_at: Time.current)

    info = uncheck(goal, today)

    expect(info).to have_attributes(done: true, sources: [ "food_entry" ])
    expect(events("goal.uncompleted").count).to eq(0)
  end

  it "lists the sources of the day ordered and without repeats" do
    Goals::GoalCheckIn.create!(goal_id: goal.id, user_id:, local_date: today, source: "food_entry", source_ref: SecureRandom.uuid, checked_at: Time.current)
    Goals::GoalCheckIn.create!(goal_id: goal.id, user_id:, local_date: today, source: "food_entry", source_ref: SecureRandom.uuid, checked_at: Time.current)

    expect(check_in(goal, today).sources).to eq(%w[food_entry manual])
  end

  it "paused and ended goals refuse check-in and uncheck with goal_not_active" do
    check_in(goal, today)

    %w[paused ended].each do |status|
      Goals::Api.change_status(user_id:, goal_id: goal.id, status:)

      [ check_in(goal, today), uncheck(goal, today) ].each do |result|
        expect(result).to have_attributes(code: "goal_not_active", details: [])
      end
    end
    expect(Goals::GoalCheckIn.count).to eq(1)
  end

  it "uses the person's time zone near midnight" do
    zone("America/Sao_Paulo")
    Goals::Goal.find(goal.id).update!(starts_on: Date.new(2026, 11, 10))

    travel_to(Time.utc(2026, 11, 18, 3, 5)) # 00:05 on the 18th in Sao Paulo (UTC-3)

    expect(check_in(goal, Date.new(2026, 11, 17))).to have_attributes(done: true)
    expect(check_in(goal, Date.new(2026, 11, 16))).to have_attributes(code: "validation_failed",
                                                                       details: [ { field: "local_date", code: "outside_window" } ])
  end

  it "the person changing time zone between check-ins" do
    Goals::Goal.find(goal.id).update!(starts_on: Date.new(2026, 11, 10))
    travel_to(Time.utc(2026, 11, 17, 22, 0))
    zone("America/Sao_Paulo")
    expect(check_in(goal, Date.new(2026, 11, 17))).to be_ok

    zone("Asia/Tokyo") # 07:00 on the 18th
    expect(check_in(goal, Date.new(2026, 11, 17))).to be_ok
    expect(check_in(goal, Date.new(2026, 11, 16))).to have_attributes(code: "validation_failed")
    expect(check_in(goal, Date.new(2026, 11, 18))).to be_ok
    expect(Goals::GoalCheckIn.where(goal_id: goal.id).order(:local_date).pluck(:local_date)).to eq([ Date.new(2026, 11, 17), Date.new(2026, 11, 18) ])
  end

  it "re-evaluating a person's recorded days gives the same results" do
    Goals::Goal.find(goal.id).update!(starts_on: yesterday)
    meal = Goals::GoalCheckIn.create!(goal_id: goal.id, user_id:, local_date: yesterday, source: "food_entry", source_ref: SecureRandom.uuid,
                                      checked_at: Time.current)
    steps = [ [ :check_in, today ], [ :check_in, yesterday ], [ :uncheck, today ], [ :uncheck, yesterday ], [ :check_in, today ], [ :check_in, today ] ]
    recorded = {}
    steps.each { |action, date| recorded[date] = Goals::Api.public_send(action, user_id:, goal_id: goal.id, local_date: date).done }

    rows = Goals::GoalCheckIn.where(goal_id: goal.id).to_a
    expect(meal).to be_persisted
    recorded.each do |date, done|
      expect(Goals::EvaluateDay.call(rule_version: Goals::Rules::CURRENT, local_date: date, check_ins: rows)).to eq(done)
    end
    expect(recorded).to eq(today => true, yesterday => true)
  end

  it "events carry only identifiers and tokens" do
    check_in(goal, today)
    uncheck(goal, today)

    (events("goal.completed").to_a + events("goal.uncompleted").to_a).each do |event|
      expect { Shared::Outbox::PayloadCheck.call(event.payload.symbolize_keys) }.not_to raise_error
      expect(event.payload.keys).not_to include("user_id", "source", "sources")
    end
  end
end

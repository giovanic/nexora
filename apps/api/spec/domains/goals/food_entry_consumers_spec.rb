require "rails_helper"
require "support/outbox_helpers"

RSpec.describe "Goals: meal consumers", :real_consumers do
  include OutboxHelpers

  let(:user_id) { new_user }
  let(:now) { Time.utc(2026, 11, 17, 15, 0) }
  let(:today) { Date.new(2026, 11, 17) }

  before do
    travel_to(now)
    allow(UserProfile::Api).to receive(:time_zone).and_return("America/Sao_Paulo")
  end

  let!(:goal) { Goals::Api.create_goal(user_id:, goal_type: "log_meals") }

  def new_user
    Identity::User.create!(email: "m-#{SecureRandom.hex(4)}@example.test", password: "correct horse battery", adult_confirmed_at: Time.current).id
  end

  def events(name) = Shared::Outbox::Event.where(name:)

  def confirm(meal_id = SecureRandom.uuid, date: today.iso8601, user: user_id)
    publish(name: "food_entry.confirmed", user_id: user, payload: { food_entry_id: meal_id, local_date: date })
    run_publisher
    meal_id
  end

  def delete_meal(meal_id, user: user_id)
    publish(name: "food_entry.deleted", user_id: user, payload: { food_entry_id: meal_id, photo_id: nil })
    run_publisher
  end

  def check_ins(goal_id = goal.id) = Goals::GoalCheckIn.where(goal_id:)

  def fake_event(name, payload, user: user_id)
    Shared::Outbox::Event.new(id: SecureRandom.uuid, name:, user_id: user, payload: payload.deep_stringify_keys)
  end

  it "a confirmed meal completes the day of an active log_meals goal and publishes goal.completed" do
    meal = confirm

    expect(check_ins.pluck(:user_id, :source, :source_ref, :local_date)).to eq([ [ user_id, "food_entry", meal, today ] ])
    expect(events("goal.completed").map { |e| e.payload["period_key"] }).to eq([ "2026-11-17" ])
  end

  it "a second meal the same day adds a check-in but no event" do
    confirm
    confirm

    expect(check_ins.count).to eq(2)
    expect(events("goal.completed").count).to eq(1)
  end

  it "the same event twice makes one check-in" do
    meal = SecureRandom.uuid
    event = fake_event("food_entry.confirmed", { food_entry_id: meal, local_date: today.iso8601 })
    2.times { expect { Goals::CheckInFromFoodEntry.call(event) }.not_to raise_error }
    expect(check_ins.count).to eq(1)

    confirm(meal)
    confirm(meal)
    expect(check_ins.count).to eq(1)
    expect(events("goal.completed").count).to eq(1)
  end

  it "a meal dated before the goal started is ignored" do
    confirm(date: (today - 1).iso8601)

    expect(check_ins.count).to eq(0)
    expect(events("goal.completed")).to be_empty
  end

  it "a paused goal ignores meals, and no check-in appears on resume" do
    Goals::Api.change_status(user_id:, goal_id: goal.id, status: "paused")
    confirm
    Goals::Api.change_status(user_id:, goal_id: goal.id, status: "active")

    expect(check_ins.count).to eq(0)
  end

  it "no log_meals goal: nothing happens" do
    other = new_user
    Goals::Api.create_goal(user_id: other, goal_type: "drink_water")
    Goals::Goal.where(user_id:).destroy_all

    confirm
    confirm(user: other)
    confirm(date: "not-a-date")

    expect(Goals::GoalCheckIn.count).to eq(0)
    expect(events("goal.completed")).to be_empty
  end

  it "ignores an invalid date for an active goal" do
    confirm(date: "not-a-date")
    confirm(date: nil)

    expect(check_ins.count).to eq(0)
  end

  it "deleting the only meal of the day publishes goal.uncompleted" do
    meal = confirm
    delete_meal(meal)

    expect(check_ins.count).to eq(0)
    expect(events("goal.uncompleted").map { |e| e.payload["period_key"] }).to eq([ "2026-11-17" ])
  end

  it "a food_entry.deleted of another person with the same meal id keeps this person's check-in and publishes nothing" do
    meal = confirm
    other = new_user
    Goals::Api.create_goal(user_id: other, goal_type: "log_meals")
    confirm(meal, user: other)

    delete_meal(meal, user: other)

    expect(check_ins.pluck(:user_id, :source_ref)).to eq([ [ user_id, meal ] ])
    expect(Goals::GoalCheckIn.where(user_id: other).count).to eq(0)
    expect(events("goal.uncompleted").pluck(:user_id)).to eq([ other ])
  end

  it "deleting one of two meals keeps the day done" do
    first = confirm
    confirm
    delete_meal(first)

    expect(check_ins.count).to eq(1)
    expect(events("goal.uncompleted")).to be_empty
  end

  it "deleting a meal keeps a manual check-in of the same day" do
    Goals::Api.check_in(user_id:, goal_id: goal.id, local_date: today)
    meal = confirm
    delete_meal(meal)

    expect(check_ins.pluck(:source)).to eq([ "manual" ])
    expect(events("goal.uncompleted")).to be_empty
  end

  it "events for a deleted goal or account finish without error" do
    meal = SecureRandom.uuid
    confirmed = fake_event("food_entry.confirmed", { food_entry_id: meal, local_date: today.iso8601 })
    deleted = fake_event("food_entry.deleted", { food_entry_id: meal, photo_id: nil })
    Goals::Goal.find(goal.id).destroy!

    expect { Goals::CheckInFromFoodEntry.call(confirmed) }.not_to raise_error
    expect { Goals::RemoveFoodEntryCheckIn.call(deleted) }.not_to raise_error

    ghost = SecureRandom.uuid
    publish(name: "food_entry.confirmed", user_id: ghost, payload: { food_entry_id: meal, local_date: today.iso8601 })
    publish(name: "food_entry.deleted", user_id: ghost, payload: { food_entry_id: meal, photo_id: nil })
    expect { run_publisher }.not_to raise_error
    expect(Shared::Outbox::Event.where(user_id: ghost).count).to eq(2)
    expect(Goals::GoalCheckIn.count).to eq(0)
  end

  it "other goal types are not touched by meals" do
    other = new_user
    water = Goals::Api.create_goal(user_id: other, goal_type: "drink_water")
    confirm(user: other)
    delete_meal(SecureRandom.uuid, user: other)

    expect(check_ins(water.id).count).to eq(0)
    expect(events("goal.completed")).to be_empty
  end
end

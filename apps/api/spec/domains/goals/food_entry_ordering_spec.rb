require "rails_helper"
require "support/outbox_helpers"

# food_entry.confirmed and food_entry.deleted of one meal can arrive in any order. Both consumers take the same
# per-person lock (Goals::MealEventLock), and the deletion leaves a marker the confirmation checks, so the meal never
# counts after it is gone. The overlapping cases are in food_entry_ordering_concurrency_spec.rb.
RSpec.describe "Goals: meal event ordering" do
  include OutboxHelpers

  let(:user_id) { Identity::User.create!(email: "o-#{SecureRandom.hex(4)}@example.test", password: "correct horse battery", adult_confirmed_at: Time.current).id }
  let(:other_id) { Identity::User.create!(email: "o-#{SecureRandom.hex(4)}@example.test", password: "correct horse battery", adult_confirmed_at: Time.current).id }
  let(:today) { Date.new(2026, 11, 17) }
  let(:meal) { SecureRandom.uuid }

  before do
    travel_to(Time.utc(2026, 11, 17, 15, 0))
    allow(UserProfile::Api).to receive(:time_zone).and_return("America/Sao_Paulo")
  end

  def goal_for(id) = Goals::Api.create_goal(user_id: id, goal_type: "log_meals")

  def event(name, payload, user: user_id)
    Shared::Outbox::Event.new(id: SecureRandom.uuid, name:, user_id: user, payload: payload.deep_stringify_keys)
  end

  def confirm(meal_id = meal, user: user_id) = Goals::CheckInFromFoodEntry.call(event("food_entry.confirmed", { food_entry_id: meal_id, local_date: today.iso8601 }, user:))
  def delete(meal_id = meal, user: user_id) = Goals::RemoveFoodEntryCheckIn.call(event("food_entry.deleted", { food_entry_id: meal_id }, user:))
  def names = Shared::Outbox::Event.where(name: %w[goal.completed goal.uncompleted]).order(:occurred_at, :id).pluck(:name)

  it "deletion handled before confirmation leaves no check-in and no event" do
    goal = goal_for(user_id)

    delete
    confirm

    expect(Goals::GoalCheckIn.where(goal_id: goal.id)).to be_empty
    expect(names).not_to include("goal.completed")
  end

  it "the marker is per person" do
    goal = goal_for(user_id)
    goal_for(other_id)

    delete(meal, user: other_id)
    confirm

    expect(Goals::GoalCheckIn.where(goal_id: goal.id, source_ref: meal).count).to eq(1)
  end

  it "deleting twice keeps one marker" do
    goal_for(user_id)

    2.times { delete }

    expect(Goals::RemovedFoodEntry.where(user_id:, food_entry_id: meal).count).to eq(1)
  end

  it "confirmation then deletion still removes the check-in and publishes goal.uncompleted" do
    goal = goal_for(user_id)

    confirm
    expect(Goals::GoalCheckIn.where(goal_id: goal.id).count).to eq(1)
    delete

    expect(Goals::GoalCheckIn.where(goal_id: goal.id)).to be_empty
    expect(names).to match_array(%w[goal.completed goal.uncompleted])
  end

  it "a deletion for a person without a log_meals goal still leaves the marker" do
    delete
    expect(Goals::RemovedFoodEntry.where(user_id:, food_entry_id: meal).count).to eq(1)
  end
end

require "rails_helper"
require "support/outbox_helpers"

RSpec.describe "Goals: create, pause, end and delete" do
  include OutboxHelpers

  let(:ana) { new_user }
  let(:bia) { new_user }

  def new_user = Identity::User.create!(email: "m-#{SecureRandom.hex(4)}@example.test", password: "correct horse battery", adult_confirmed_at: Time.current).id

  def events(name) = Shared::Outbox::Event.where(name:)

  it "creates a daily goal of an allowed type and publishes goal.created" do
    info = Goals::Api.create_goal(user_id: ana, goal_type: "drink_water")

    expect(info).to be_ok
    expect(info).to have_attributes(goal_type: "drink_water", status: "active", created: true, done_today: false, done_yesterday: false,
                                    starts_on: Goals::LocalDay.today(user_id: ana), ends_on: nil)
    expect(Goals::Goal.find(info.id).rule_version).to eq(Goals::Rules::CURRENT)
    expect(events("goal.created").map(&:payload)).to eq([ { "goal_id" => info.id, "goal_type" => "drink_water" } ])
  end

  it "lists the goal types" do
    expect(Goals::Api.goal_types).to eq(Goals::GoalType::ALL)
  end

  it "rejects forbidden types with a neutral validation error" do
    (%w[calorie_target calorie_limit calorie_deficit weight_loss target_weight fasting burn_to_eat LOG_MEALS] + [ nil ]).each do |type|
      result = Goals::Api.create_goal(user_id: ana, goal_type: type)

      expect(result).not_to be_ok
      expect(result).to have_attributes(code: "validation_failed", details: [ { field: "goal_type", code: "unsupported_goal_type" } ])
    end
    expect(Goals::Goal.count).to eq(0)
    expect(Shared::Outbox::Event.count).to eq(0)
  end

  it "returns the live goal of the same type instead of a second one" do
    first = Goals::Api.create_goal(user_id: ana, goal_type: "log_meals")
    Goals::Api.change_status(user_id: ana, goal_id: first.id, status: "paused")

    again = Goals::Api.create_goal(user_id: ana, goal_type: "log_meals")

    expect(again).to have_attributes(id: first.id, created: false, status: "paused")
    expect(Goals::Goal.count).to eq(1)
    expect(events("goal.created").count).to eq(1)
  end

  it "pauses, resumes and ends" do
    id = Goals::Api.create_goal(user_id: ana, goal_type: "sleep_routine").id
    today = Goals::LocalDay.today(user_id: ana)

    paused = Goals::Api.change_status(user_id: ana, goal_id: id, status: "paused")
    expect(paused).to have_attributes(status: "paused")
    expect(Goals::Goal.find(id).paused_at).to be_present

    expect(Goals::Api.change_status(user_id: ana, goal_id: id, status: "paused")).to have_attributes(status: "paused")

    resumed = Goals::Api.change_status(user_id: ana, goal_id: id, status: "active")
    expect(resumed).to have_attributes(status: "active")
    expect(Goals::Goal.find(id).paused_at).to be_nil

    ended = Goals::Api.change_status(user_id: ana, goal_id: id, status: "ended")
    expect(ended).to have_attributes(status: "ended", ends_on: today)
    expect(Shared::Outbox::Event.pluck(:name)).to eq([ "goal.created" ])
  end

  it "rejects an unknown status" do
    id = Goals::Api.create_goal(user_id: ana, goal_type: "log_meals").id

    result = Goals::Api.change_status(user_id: ana, goal_id: id, status: "deleted")

    expect(result).to have_attributes(code: "validation_failed", details: [ { field: "status", code: "inclusion" } ])
  end

  it "an ended goal cannot change status" do
    id = Goals::Api.create_goal(user_id: ana, goal_type: "log_meals").id
    Goals::Api.change_status(user_id: ana, goal_id: id, status: "ended")

    %w[active paused ended].each do |status|
      expect(Goals::Api.change_status(user_id: ana, goal_id: id, status:)).to have_attributes(code: "goal_not_active")
    end
  end

  it "after ending, the same type can be created again" do
    first = Goals::Api.create_goal(user_id: ana, goal_type: "log_meals")
    Goals::Api.change_status(user_id: ana, goal_id: first.id, status: "ended")

    second = Goals::Api.create_goal(user_id: ana, goal_type: "log_meals")

    expect(second).to have_attributes(created: true, status: "active")
    expect(second.id).not_to eq(first.id)
  end

  it "reports done_today and done_yesterday from the check-ins" do
    info = Goals::Api.create_goal(user_id: ana, goal_type: "log_meals")
    yesterday, today = Goals::LocalDay.window(user_id: ana)
    Goals::GoalCheckIn.create!(goal_id: info.id, user_id: ana, local_date: yesterday, source: "manual", checked_at: Time.current)

    view = Goals::GoalView.call(Goals::Goal.find(info.id), today:, yesterday:)

    expect(view).to have_attributes(done_today: false, done_yesterday: true)
  end

  it "delete removes the goal and its check-ins and publishes goal.deleted" do
    id = Goals::Api.create_goal(user_id: ana, goal_type: "log_meals").id
    Goals::GoalCheckIn.create!(goal_id: id, user_id: ana, local_date: Goals::LocalDay.today(user_id: ana), source: "manual", checked_at: Time.current)

    expect(Goals::Api.delete_goal(user_id: ana, goal_id: id)).to eq(:deleted)

    expect(Goals::Goal.count).to eq(0)
    expect(Goals::GoalCheckIn.count).to eq(0)
    expect(events("goal.deleted").map(&:payload)).to eq([ { "goal_id" => id } ])
  end

  it "another person's goal is not_found for change_status and delete_goal; so is a malformed id" do
    id = Goals::Api.create_goal(user_id: ana, goal_type: "log_meals").id

    expect(Goals::Api.change_status(user_id: bia, goal_id: id, status: "paused")).to eq(:not_found)
    expect(Goals::Api.delete_goal(user_id: bia, goal_id: id)).to eq(:not_found)
    expect(Goals::Api.change_status(user_id: ana, goal_id: "not-a-uuid", status: "paused")).to eq(:not_found)
    expect(Goals::Api.delete_goal(user_id: ana, goal_id: "not-a-uuid")).to eq(:not_found)
    expect(Goals::Goal.find(id).status).to eq("active")
    expect(events("goal.deleted").count).to eq(0)
  end
end

RSpec.describe "Goals concurrency" do
  self.use_transactional_tests = false

  let(:user) { Identity::User.create!(email: "gc-#{SecureRandom.hex(4)}@example.test", password: "correct horse battery", adult_confirmed_at: Time.current) }

  after { ActiveRecord::Base.connection.execute("TRUNCATE users, goals, outbox_events, audit_events CASCADE") }

  it "two concurrent creates of the same type make one goal" do
    user
    gate = Queue.new
    threads = Array.new(2) do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          Goals::Api.create_goal(user_id: user.id, goal_type: "drink_water")
        end
      end
    end
    2.times { gate << true }
    results = threads.map(&:value)

    expect(results).to all(be_ok)
    expect(results.map(&:id).uniq.size).to eq(1)
    expect(results.map(&:created)).to contain_exactly(true, false)
    expect(Goals::Goal.where(user_id: user.id).count).to eq(1)
    expect(Shared::Outbox::Event.where(name: "goal.created").count).to eq(1)
  end
end

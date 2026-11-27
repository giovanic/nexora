require "rails_helper"

# The raw inserts go around the model validations: the database itself must refuse what the product forbids.
RSpec.describe "goals schema constraints" do
  let(:user_id) { Identity::User.create!(email: "g-#{SecureRandom.hex(4)}@example.test", password: "correct horse battery", adult_confirmed_at: Time.current).id }
  let(:today) { Date.new(2026, 11, 17) }

  def goal_row(overrides = {})
    { user_id:, goal_type: "log_meals", cadence: "daily", target: 1, rule_version: "daily_any_v1", status: "active",
      starts_on: today, created_at: Time.current, updated_at: Time.current }.merge(overrides)
  end

  # A savepoint per insert: a refused statement would otherwise abort the example's transaction.
  def insert_goal(overrides = {})
    Goals::Goal.transaction(requires_new: true) { Goals::Goal.insert_all!([ goal_row(overrides) ], returning: %w[id]).first.fetch("id") }
  end

  def check_in_row(goal_id, overrides = {})
    { goal_id:, user_id:, local_date: today, source: "manual", source_ref: nil, checked_at: Time.current,
      created_at: Time.current, updated_at: Time.current }.merge(overrides)
  end

  def insert_check_in(goal_id, overrides = {})
    Goals::GoalCheckIn.transaction(requires_new: true) { Goals::GoalCheckIn.insert_all!([ check_in_row(goal_id, overrides) ]) }
  end

  it "rejects a forbidden goal type inserted directly" do
    %w[calorie_target calorie_limit calorie_deficit weight_loss target_weight fasting burn_to_eat].each do |type|
      expect { insert_goal(goal_type: type) }.to raise_error(ActiveRecord::CheckViolation, /goals_goal_type_allowed/)
    end
  end

  it "accepts each allowed type" do
    expect(Goals::GoalType::ALL).to eq(%w[log_meals include_fruits_vegetables drink_water sleep_routine planned_workout])
    expect(Goals::GoalType::ALL).to be_frozen
    Goals::GoalType::ALL.each { |type| expect { insert_goal(goal_type: type) }.not_to raise_error }
    expect(Goals::GoalType.allowed?("drink_water")).to be(true)
    expect(Goals::GoalType.allowed?("calorie_limit")).to be(false)
  end

  it "rejects weekly cadence and a target other than 1" do
    expect { insert_goal(cadence: "weekly") }.to raise_error(ActiveRecord::CheckViolation, /goals_cadence_daily/)
    expect { insert_goal(target: 2) }.to raise_error(ActiveRecord::CheckViolation, /goals_target_one/)
    expect { insert_goal(status: "done") }.to raise_error(ActiveRecord::CheckViolation, /goals_status_known/)
    expect { insert_goal(status: "ended") }.to raise_error(ActiveRecord::CheckViolation, /goals_ended_has_end/)
  end

  it "allows one live goal per type" do
    insert_goal
    expect { insert_goal }.to raise_error(ActiveRecord::RecordNotUnique)
    expect { insert_goal(status: "paused") }.to raise_error(ActiveRecord::RecordNotUnique)
    expect { insert_goal(goal_type: "drink_water") }.not_to raise_error

    Goals::Goal.where(user_id:, goal_type: "log_meals").update_all(status: "ended", ends_on: today)
    expect { insert_goal }.not_to raise_error
  end

  it "allows one manual check-in per goal and day" do
    goal_id = insert_goal
    insert_check_in(goal_id)

    expect { insert_check_in(goal_id) }.to raise_error(ActiveRecord::RecordNotUnique)
    expect { insert_check_in(goal_id, local_date: today - 1) }.not_to raise_error
  end

  it "allows one check-in per goal and meal" do
    goal_id = insert_goal
    meal = SecureRandom.uuid
    insert_check_in(goal_id, source: "food_entry", source_ref: meal)

    expect { insert_check_in(goal_id, source: "food_entry", source_ref: meal) }.to raise_error(ActiveRecord::RecordNotUnique)
    expect { insert_check_in(goal_id, source: "food_entry", source_ref: SecureRandom.uuid) }.not_to raise_error
  end

  it "requires source_ref exactly for food_entry" do
    goal_id = insert_goal

    expect { insert_check_in(goal_id, source: "manual", source_ref: SecureRandom.uuid) }
      .to raise_error(ActiveRecord::CheckViolation, /goal_check_ins_ref_matches_source/)
    expect { insert_check_in(goal_id, source: "food_entry", source_ref: nil) }
      .to raise_error(ActiveRecord::CheckViolation, /goal_check_ins_ref_matches_source/)
    expect { insert_check_in(goal_id, source: "activity", source_ref: SecureRandom.uuid) }
      .to raise_error(ActiveRecord::CheckViolation, /goal_check_ins_source_known/)
  end

  it "deleting a goal deletes its check-ins" do
    goal_id = insert_goal
    insert_check_in(goal_id)

    Goals::Goal.where(id: goal_id).delete_all

    expect(Goals::GoalCheckIn.where(goal_id:).count).to eq(0)
  end

  it "refuses a check-in whose owner is not the owner of the goal" do
    goal_id = insert_goal
    other_id = Identity::User.create!(email: "g-#{SecureRandom.hex(4)}@example.test", password: "correct horse battery", adult_confirmed_at: Time.current).id

    expect { insert_check_in(goal_id, user_id: other_id) }.to raise_error(ActiveRecord::InvalidForeignKey, /goal_check_ins_goal_owner/)
    expect { insert_check_in(goal_id) }.not_to raise_error
  end

  it "allows one removed-meal marker per person and meal" do
    meal = SecureRandom.uuid
    row = ->(overrides = {}) { { user_id:, food_entry_id: meal, created_at: Time.current }.merge(overrides) }
    insert = ->(attrs) { Goals::RemovedFoodEntry.transaction(requires_new: true) { Goals::RemovedFoodEntry.insert_all!([ attrs ]) } }
    insert.call(row.call)

    expect { insert.call(row.call) }.to raise_error(ActiveRecord::RecordNotUnique)
    expect { insert.call(row.call(food_entry_id: SecureRandom.uuid)) }.not_to raise_error
  end
end

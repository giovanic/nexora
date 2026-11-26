require "rails_helper"

# Taps at the same time, each on its own connection. The goal is locked for each change, so the day gets one
# check-in and one goal.completed whatever the order.
RSpec.describe "Goals check-in concurrency" do
  self.use_transactional_tests = false

  let(:user) { Identity::User.create!(email: "gc-#{SecureRandom.hex(4)}@example.test", password: "correct horse battery", adult_confirmed_at: Time.current) }
  let!(:goal) { Goals::Api.create_goal(user_id: user.id, goal_type: "log_meals") }
  let(:today) { Goals::LocalDay.today(user_id: user.id) }

  after { ActiveRecord::Base.connection.execute("TRUNCATE users, goals, goal_check_ins, outbox_events, audit_events CASCADE") }

  def together(*blocks)
    gate = Queue.new
    threads = blocks.map do |block|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          gate.pop
          block.call
        end
      end
    end
    blocks.size.times { gate << true }
    threads.map(&:value)
  end

  def completed = Shared::Outbox::Event.where(name: "goal.completed").count

  it "two check-ins on the same day give one check-in and one goal.completed" do
    results = together(*Array.new(2) { -> { Goals::Api.check_in(user_id: user.id, goal_id: goal.id, local_date: today) } })

    expect(results).to all(be_ok)
    expect(results.map(&:done)).to all(be(true))
    expect(Goals::GoalCheckIn.where(goal_id: goal.id, source: "manual").count).to eq(1)
    expect(completed).to eq(1)
  end

  it "a check-in together with a meal check-in gives one goal.completed" do
    meal = lambda do
      Goals::Goal.transaction do
        record = Goals::Goal.find(goal.id)
        Goals::RecordDay.call(goal: record, local_date: today) do
          Goals::GoalCheckIn.create!(goal_id: record.id, user_id: record.user_id, local_date: today, source: "food_entry",
                                     source_ref: SecureRandom.uuid, checked_at: Time.current)
        end
      end
    end

    together(-> { Goals::Api.check_in(user_id: user.id, goal_id: goal.id, local_date: today) }, meal)

    expect(Goals::GoalCheckIn.where(goal_id: goal.id).pluck(:source).sort).to eq(%w[food_entry manual])
    expect(completed).to eq(1)
    expect(Shared::Outbox::Event.where(name: "goal.uncompleted").count).to eq(0)
  end
end

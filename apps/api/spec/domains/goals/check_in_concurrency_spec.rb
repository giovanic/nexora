require "rails_helper"

# Taps at the same time, each on its own connection. The goal is locked for each change, so the day gets one
# check-in and one goal.completed whatever the order.
RSpec.describe "Goals check-in concurrency" do
  self.use_transactional_tests = false

  let(:user) { Identity::User.create!(email: "gc-#{SecureRandom.hex(4)}@example.test", password: "correct horse battery", adult_confirmed_at: Time.current) }
  let!(:goal) { Goals::Api.create_goal(user_id: user.id, goal_type: "log_meals") }
  let(:today) { Goals::LocalDay.today(user_id: user.id) }

  after { ActiveRecord::Base.connection.execute("TRUNCATE users, goals, goal_check_ins, outbox_events, audit_events CASCADE") }

  def completed = Shared::Outbox::Event.where(name: "goal.completed").count

  # The first call holds its transaction open inside RecordDay until the second has started and had time to block.
  # Without the goal lock the second one runs meanwhile, both see "not done" and two goal.completed are published.
  def overlapping(first, second)
    started = Queue.new
    release = Queue.new
    a = Thread.new { ActiveRecord::Base.connection_pool.with_connection { first.call(started, release) } }
    started.pop
    b = Thread.new { ActiveRecord::Base.connection_pool.with_connection { second.call } }
    sleep 0.5
    release << true
    [ a.value, b.value ]
  end

  def holding(date, check_in_attrs)
    lambda do |started, release|
      Goals::Goal.transaction do
        record = Goals::Goal.find(goal.id)
        Goals::RecordDay.call(goal: record, local_date: date) do
          started << true
          release.pop
          Goals::GoalCheckIn.insert_all([ { goal_id: record.id, user_id: record.user_id, local_date: date, checked_at: Time.current }.merge(check_in_attrs) ])
        end
      end
    end
  end

  it "two check-ins on the same day give one check-in and one goal.completed" do
    date = today
    results = overlapping(holding(date, source: "manual"), -> { Goals::Api.check_in(user_id: user.id, goal_id: goal.id, local_date: date) })

    expect(results.last).to be_ok
    expect(results.last.done).to be(true)
    expect(Goals::GoalCheckIn.where(goal_id: goal.id, source: "manual").count).to eq(1)
    expect(completed).to eq(1)
  end

  it "a check-in together with a meal check-in gives one goal.completed" do
    date = today
    overlapping(holding(date, source: "food_entry", source_ref: SecureRandom.uuid), -> { Goals::Api.check_in(user_id: user.id, goal_id: goal.id, local_date: date) })

    expect(Goals::GoalCheckIn.where(goal_id: goal.id).pluck(:source).sort).to eq(%w[food_entry manual])
    expect(completed).to eq(1)
    expect(Shared::Outbox::Event.where(name: "goal.uncompleted").count).to eq(0)
  end
end

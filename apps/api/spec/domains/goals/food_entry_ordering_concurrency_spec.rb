require "rails_helper"

# The confirmation of a meal holds the goal lock and is not committed yet when the deletion of the same meal starts,
# each on its own connection. The deletion has to wait for the lock, then see the check-in and remove it.
RSpec.describe "Goals meal ordering concurrency" do
  self.use_transactional_tests = false

  let(:user) { Identity::User.create!(email: "oc-#{SecureRandom.hex(4)}@example.test", password: "correct horse battery", adult_confirmed_at: Time.current) }
  let!(:goal) { Goals::Api.create_goal(user_id: user.id, goal_type: "log_meals") }
  let(:today) { Goals::LocalDay.today(user_id: user.id) }
  let(:meal) { SecureRandom.uuid }

  after { ActiveRecord::Base.connection.execute("TRUNCATE users, goals, goal_check_ins, goal_removed_food_entries, outbox_events, audit_events CASCADE") }

  def names = Shared::Outbox::Event.where(name: %w[goal.completed goal.uncompleted]).order(:occurred_at, :id).pluck(:name)

  it "a deletion that starts while the confirmation is uncommitted leaves no check-in and balanced events" do
    date = today
    started = Queue.new
    release = Queue.new

    confirming = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        Goals::Goal.transaction do
          record = Goals::Goal.find(goal.id)
          Goals::RecordDay.call(goal: record, local_date: date) do
            started << true
            release.pop
            Goals::GoalCheckIn.insert_all([ { goal_id: record.id, user_id: record.user_id, local_date: date, source: "food_entry", source_ref: meal, checked_at: Time.current } ])
          end
        end
      end
    end
    started.pop
    event = Shared::Outbox::Event.new(id: SecureRandom.uuid, name: "food_entry.deleted", user_id: user.id, payload: { "food_entry_id" => meal })
    deleting = Thread.new { ActiveRecord::Base.connection_pool.with_connection { Goals::RemoveFoodEntryCheckIn.call(event) } }
    sleep 0.5
    release << true
    [ confirming, deleting ].each(&:join)

    expect(Goals::GoalCheckIn.where(goal_id: goal.id)).to be_empty
    expect(names).to eq(%w[goal.completed goal.uncompleted])
    expect(Goals::RemovedFoodEntry.where(user_id: user.id, food_entry_id: meal).count).to eq(1)
  end
end

require "rails_helper"

# The real consumers, each on its own connection and with no spec transaction. The first one runs inside a transaction
# that stays open until released; the second starts meanwhile and must wait for the per-person lock.
RSpec.describe "Goals meal ordering concurrency" do
  self.use_transactional_tests = false

  let!(:user) { Identity::User.create!(email: "oc-#{SecureRandom.hex(4)}@example.test", password: "correct horse battery", adult_confirmed_at: Time.current) }
  let(:meal) { SecureRandom.uuid }
  let!(:date) { Goals::LocalDay.today(user_id: user.id) }

  after do
    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute("SET LOCAL lock_timeout = '5s'")
      ActiveRecord::Base.connection.execute("TRUNCATE users, goals, goal_check_ins, goal_removed_food_entries, outbox_events, audit_events CASCADE")
    end
  end

  def names = Shared::Outbox::Event.where(name: %w[goal.completed goal.uncompleted]).order(:occurred_at, :id).pluck(:name)
  def check_ins = Goals::GoalCheckIn.where(user_id: user.id)
  def confirmed = Shared::Outbox::Event.new(id: SecureRandom.uuid, name: "food_entry.confirmed", user_id: user.id, payload: { "food_entry_id" => meal, "local_date" => date.iso8601 })
  def deleted = Shared::Outbox::Event.new(id: SecureRandom.uuid, name: "food_entry.deleted", user_id: user.id, payload: { "food_entry_id" => meal })

  # Runs `first` and keeps its transaction open until released; runs `second` meanwhile; `between` runs on the main
  # thread after the first has done its work and before the second starts.
  # The first is released only once the second is really waiting on a database lock, or has already finished (then
  # nothing made it wait, and the expectations catch that), so a slow machine cannot turn the spec into a false pass.
  def overlapping(first:, second:, between: nil)
    started = Queue.new
    release = Queue.new
    b = nil
    a = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        Goals::Goal.transaction do
          first.call
        ensure
          started << true
          release.pop(timeout: WAIT)
        end
      end
    ensure
      started << true
    end
    begin
      raise "the first transaction never started" unless started.pop(timeout: WAIT)
      between&.call
      b = Thread.new { ActiveRecord::Base.connection_pool.with_connection { second.call } }
      wait_until_waiting_or_done(b)
    ensure
      release << true
      [ a, b ].compact.each { |thread| thread.join(WAIT) or raise "a thread did not finish" }
    end
  end

  WAIT = 10

  def wait_until_waiting_or_done(thread)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + WAIT
    loop do
      return unless thread.alive?
      return if ActiveRecord::Base.connection.select_value("SELECT count(*) FROM pg_locks WHERE NOT granted").positive?
      raise "the second consumer neither waited nor finished" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.01
    end
  end

  it "a deletion that starts while the confirmation is uncommitted removes its check-in and balances the events" do
    Goals::Api.create_goal(user_id: user.id, goal_type: "log_meals")

    overlapping(first: -> { Goals::CheckInFromFoodEntry.call(confirmed) }, second: -> { Goals::RemoveFoodEntryCheckIn.call(deleted) })

    expect(check_ins).to be_empty
    expect(names).to eq(%w[goal.completed goal.uncompleted])
    expect(Goals::RemovedFoodEntry.where(user_id: user.id, food_entry_id: meal).count).to eq(1)
  end

  it "a confirmation that starts while the deletion is uncommitted sees the marker and records nothing" do
    Goals::Api.create_goal(user_id: user.id, goal_type: "log_meals")

    overlapping(first: -> { Goals::RemoveFoodEntryCheckIn.call(deleted) }, second: -> { Goals::CheckInFromFoodEntry.call(confirmed) })

    expect(check_ins).to be_empty
    expect(names).to be_empty
  end

  it "a log_meals goal created while the deletion is uncommitted does not let the confirmation through" do
    overlapping(first: -> { Goals::RemoveFoodEntryCheckIn.call(deleted) }, second: -> { Goals::CheckInFromFoodEntry.call(confirmed) },
                between: -> { Goals::Api.create_goal(user_id: user.id, goal_type: "log_meals") })

    expect(check_ins).to be_empty
    expect(names).to be_empty
  end
end

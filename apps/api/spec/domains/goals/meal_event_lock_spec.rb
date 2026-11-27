require "rails_helper"

RSpec.describe Goals::MealEventLock do
  it "refuses a missing person, which would share one lock among every such event" do
    [ nil, "" ].each do |user_id|
      expect { Goals::Goal.transaction { described_class.acquire(user_id) } }.to raise_error(ArgumentError, /user_id/)
    end
  end

  it "takes a transaction-scoped advisory lock for the person" do
    user_id = SecureRandom.uuid
    Goals::Goal.transaction do
      described_class.acquire(user_id)
      held = Goals::Goal.connection.select_value("SELECT count(*) FROM pg_locks WHERE locktype = 'advisory' AND granted AND pid = pg_backend_pid()")
      expect(held).to eq(1)
    end
  end

  # Held here, tried on another connection with a short lock_timeout. Without the spec transaction, because with it
  # every thread shares one connection, and an advisory lock is reentrant within its session. No rows are written.
  describe "between connections" do
    self.use_transactional_tests = false

    def try_on_other_connection(user_id)
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Goals::Goal.transaction do
            Goals::Goal.connection.execute("SET LOCAL lock_timeout = '300ms'")
            described_class.acquire(user_id)
            :acquired
          end
        rescue ActiveRecord::LockWaitTimeout
          :waited
        end
      end.value
    end

    it "makes the same person wait and lets another person through" do
      held = SecureRandom.uuid
      Goals::Goal.transaction do
        described_class.acquire(held)

        expect(try_on_other_connection(held)).to eq(:waited)
        expect(try_on_other_connection(SecureRandom.uuid)).to eq(:acquired)
      end
    end
  end

  describe "outside a transaction" do
    self.use_transactional_tests = false

    it "refuses, because the lock would last only for that one statement" do
      expect { described_class.acquire(SecureRandom.uuid) }.to raise_error(ArgumentError, /transaction/)
    end
  end
end

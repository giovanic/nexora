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
end

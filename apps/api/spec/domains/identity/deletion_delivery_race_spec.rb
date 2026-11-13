require "rails_helper"
require "support/outbox_helpers"

# Ruling R40: a consumer that is mid-delivery when the deletion is requested
# must not leave its row behind. Committed rows and real threads.
RSpec.describe "account deletion requested during an event delivery", :real_consumers do
  include OutboxHelpers

  self.use_transactional_tests = false

  let(:password) { "correct horse battery" }
  let!(:user_id) do
    Identity::Api.register(email: "ana@example.test", password:, adult_confirmed: true,
                           time_zone: "America/Sao_Paulo", client: "mobile", device_label: nil, ip: nil).user_id
  end

  before do
    allow(Identity::EraseAccountJob).to receive(:perform_async)
    # Today the outbox eraser runs before User Profile's and waits for the
    # locked event row, which would hide the race. The guarantee must not rest
    # on the order of the registry, so the outbox eraser does nothing here.
    Shared::DataRegistry.register(context: "shared", tables: %w[outbox_events], exporter: ->(_user_id) { {} }, eraser: ->(_user_id) { })
  end

  after do
    ActiveRecord::Base.connection.execute("TRUNCATE users, outbox_events, account_deletions, audit_events CASCADE")
  end

  it "leaves no profile row after the erasure, however the two interleave" do
    inside = Queue.new
    release = Queue.new
    # The delivery passed the discard rule and is writing its row when the request arrives.
    allow(UserProfile::CreateProfile).to receive(:call).and_wrap_original do |original, event|
      inside << true
      release.pop
      original.call(event)
    end

    delivery = Thread.new { ActiveRecord::Base.connection_pool.with_connection { run_publisher } }
    inside.pop
    deletion = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        Identity::Api.request_deletion(user_id:, password:, ip: nil)
        Identity::EraseAccountJob.new.perform(Identity::AccountDeletion.find_by!(user_id:).id)
      end
    end
    sleep 0.5
    release << true
    [ delivery, deletion ].each(&:join)

    expect(UserProfile::Profile.where(user_id:)).to be_empty
    expect(Identity::AccountDeletion.find_by!(user_id:).completed_at).to be_present
  end

  it "discards an event delivered after the request" do
    Identity::Api.request_deletion(user_id:, password:, ip: nil)

    run_publisher

    expect(UserProfile::Profile.where(user_id:)).to be_empty
  end
end

require "rails_helper"
require "support/outbox_helpers"

# AC-02-12: the outbox delivers user.deletion_requested even when a consumer
# fails, a redelivery has no second effect, and the reconciliation names a
# consumer that never applied it. The event comes from the real request.
RSpec.describe "user.deletion_requested delivery", :real_consumers do
  include OutboxHelpers
  include SentryCapture

  let(:password) { "correct horse battery" }
  let(:user_id) do
    Identity::Api.register(email: "ana@example.test", password:, adult_confirmed: true, time_zone: "America/Sao_Paulo",
                           client: "mobile", device_label: nil, ip: nil).user_id
  end
  let(:effects) { Hash.new { |hash, key| hash[key] = [] } }

  before { allow(Identity::EraseAccountJob).to receive(:perform_async) }

  def request_deletion
    expect(Identity::Api.request_deletion(user_id:, password:, ip: nil)).to eq(:scheduled)
    Shared::Outbox::Event.find_by!(name: "user.deletion_requested", user_id:)
  end

  it "is delivered after the consumer fails, once, without a duplicate effect" do
    failures = 2
    Shared::Outbox.subscribe("user.deletion_requested", consumer: "planted.revoke_access") do |event|
      raise "provider unavailable" if (failures -= 1) >= 0

      effects["planted.revoke_access"] << event.id
    end
    Shared::Outbox.subscribe("user.deletion_requested", consumer: "planted.forget_device") { |event| effects["planted.forget_device"] << event.id }
    event = request_deletion

    run_publisher
    expect(event.reload).to have_attributes(published_at: nil, attempts: 1)
    travel_to(event.next_attempt_at + 1.second) { run_publisher }
    expect(event.reload).to have_attributes(published_at: nil, attempts: 2)
    travel_to(event.next_attempt_at + 1.second) { run_publisher }

    expect(event.reload.published_at).to be_present
    expect(effects).to eq("planted.revoke_access" => [ event.id ], "planted.forget_device" => [ event.id ])

    # A redelivery, as after a crash before the bookkeeping, changes nothing.
    event.update_columns(published_at: nil, next_attempt_at: nil)
    run_publisher
    expect(effects).to eq("planted.revoke_access" => [ event.id ], "planted.forget_device" => [ event.id ])
    expect(Shared::Outbox::ConsumedEvent.where(event_id: event.id).pluck(:consumer)).to contain_exactly("planted.revoke_access", "planted.forget_device")
  end

  it "the erasure keeps the event until it is delivered" do
    Shared::Outbox.subscribe("user.deletion_requested", consumer: "planted.revoke_access") { |_event| raise "provider unavailable" }
    event = request_deletion
    run_publisher

    Identity::EraseAccountJob.new.perform(Identity::AccountDeletion.find_by!(user_id:).id)

    expect(Shared::Outbox::Event.where(user_id:).pluck(:id)).to eq([ event.id ])
  end

  it "reconcile reports a consumer missing for user.deletion_requested" do
    Shared::Outbox.subscribe("user.deletion_requested", consumer: "planted.revoke_access") { |event| effects["ok"] << event.id }
    Shared::Outbox.subscribe("user.deletion_requested", consumer: "planted.forget_device") { |_event| raise "provider unavailable" }
    event = travel_to(2.hours.ago) { request_deletion }
    travel_to(event.occurred_at) { run_publisher }

    report = Shared::Outbox::ReconcileJob.new.perform

    expect(report).to include({ event: "user.deletion_requested", consumer: "planted.forget_device", count: 1 })
    expect(report.map { |line| line[:consumer] }).not_to include("planted.revoke_access")
    alert = sentry_events.find { |sentry_event| sentry_event.tags[:outbox_consumer] == "planted.forget_device" }
    expect(alert.tags).to include(outbox_event: "user.deletion_requested")
    expect(alert.to_json_compatible.to_json).not_to include("ana@example.test", user_id)
  end
end

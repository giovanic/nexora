require "rails_helper"
require "support/outbox_helpers"

RSpec.describe Shared::Outbox::ReconcileJob do
  include OutboxHelpers
  include SentryCapture

  before do
    Shared::Outbox.subscribe("user.registered", consumer: "user_profile.create_profile") { |_event| nil }
    Shared::Outbox.subscribe("user.registered", consumer: "goals.prepare") { |_event| nil }
  end

  def consume(event, consumer)
    Shared::Outbox::ConsumedEvent.create!(consumer:, event_id: event.id, consumed_at: Time.current)
  end

  def publish_hours_ago(hours, **options)
    travel_to(hours.hours.ago) { publish(**options) }
  end

  it "reconcile reports a missing consumer" do
    user_id = SecureRandom.uuid
    event = publish_hours_ago(2, user_id:, payload: { "profile_id" => "profile-secret-id" })
    consume(event, "user_profile.create_profile")

    report = described_class.new.perform

    expect(report).to eq([ { event: "user.registered", consumer: "goals.prepare", count: 1 } ])
    expect(sentry_events.size).to eq(1)
    alert = sentry_events.first
    expect(alert.exception.values.first.type).to eq("Shared::Outbox::MissingConsumption")
    expect(alert.tags).to include(outbox_event: "user.registered", outbox_consumer: "goals.prepare")
    serialized = alert.to_json_compatible.to_json
    [ user_id, event.id, "profile-secret-id" ].each { |value| expect(serialized).not_to include(value) }
  end

  it "counts the events missing for each consumer" do
    2.times { publish_hours_ago(2) }

    report = described_class.new.perform

    expect(report).to contain_exactly(
      { event: "user.registered", consumer: "user_profile.create_profile", count: 2 },
      { event: "user.registered", consumer: "goals.prepare", count: 2 }
    )
  end

  it "waits an hour before reporting" do
    publish_hours_ago(0.5)

    expect(described_class.new.perform).to eq([])
    expect(sentry_events).to be_empty
  end

  it "does not report an event every consumer received" do
    event = publish_hours_ago(2)
    consume(event, "user_profile.create_profile")
    consume(event, "goals.prepare")

    expect(described_class.new.perform).to eq([])
  end

  it "leaves dead events to their own alert" do
    event = publish_hours_ago(3)
    event.update!(dead_at: 1.hour.ago, attempts: 8)

    expect(described_class.new.perform).to eq([])
  end

  it "does not report published events for a consumer subscribed after they were published" do
    event = publish_hours_ago(2)
    consume(event, "user_profile.create_profile")
    consume(event, "goals.prepare")
    event.update!(published_at: 2.hours.ago)
    Shared::Outbox.subscribe("user.registered", consumer: "missions.prepare") { |_event| nil }

    expect(described_class.new.perform).to eq([])
  end
end

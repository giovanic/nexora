require "rails_helper"
require "support/outbox_helpers"

RSpec.describe Shared::Outbox::PublishJob do
  include OutboxHelpers

  let(:received) { Hash.new { |hash, key| hash[key] = [] } }

  def subscribe(consumer, event_name: "user.registered", &handler)
    handler ||= ->(event) { received[consumer] << event.id }
    Shared::Outbox.subscribe(event_name, consumer:, &handler)
  end

  # A little past the wait: travel_to drops microseconds, which would land just before it.
  def after_wait(event, &block)
    due = event.reload.next_attempt_at
    due ? travel_to(due + 1.second, &block) : yield
  end

  def consumed(event)
    Shared::Outbox::ConsumedEvent.where(event_id: event.id).pluck(:consumer)
  end

  it "delivers a pending event to each consumer and marks it published" do
    subscribe("user_profile.create_profile")
    subscribe("goals.prepare")
    event = publish

    run_publisher

    expect(received).to eq("user_profile.create_profile" => [ event.id ], "goals.prepare" => [ event.id ])
    expect(consumed(event)).to contain_exactly("user_profile.create_profile", "goals.prepare")
    expect(event.reload.published_at).to be_present
  end

  it "only delivers an event to the consumers of its name" do
    subscribe("identity.purge", event_name: "user.deletion_requested")
    publish(name: "user.registered")

    run_publisher

    expect(received).to be_empty
  end

  it "marks published an event nobody consumes" do
    event = publish

    run_publisher

    expect(event.reload.published_at).to be_present
  end

  it "delivers once even if run twice" do
    subscribe("user_profile.create_profile")
    event = publish

    2.times { run_publisher }

    expect(received["user_profile.create_profile"]).to eq([ event.id ])
  end

  it "delivers once when the event was already consumed, as after a crash before marking it published" do
    subscribe("user_profile.create_profile")
    event = publish
    Shared::Outbox::ConsumedEvent.create!(consumer: "user_profile.create_profile", event_id: event.id, consumed_at: Time.current)

    run_publisher

    expect(received["user_profile.create_profile"]).to eq([])
    expect(event.reload.published_at).to be_present
  end

  it "retries a failing consumer without repeating the ones that succeeded" do
    failures = 1
    subscribe("user_profile.create_profile")
    subscribe("goals.prepare") do |event|
      if failures.positive?
        failures -= 1
        raise "temporary failure"
      end
      received["goals.prepare"] << event.id
    end
    event = publish

    run_publisher

    expect(event.reload).to have_attributes(attempts: 1, published_at: nil, dead_at: nil)
    expect(consumed(event)).to eq([ "user_profile.create_profile" ])

    after_wait(event) { run_publisher }

    expect(received).to eq("user_profile.create_profile" => [ event.id ], "goals.prepare" => [ event.id ])
    expect(event.reload.published_at).to be_present
  end

  it "undoes the effect of a consumer that fails halfway" do
    subscribe("goals.prepare") do |event|
      Shared::Outbox::Event.where(id: event.id).update_all(correlation_id: "half-done")
      raise "failure after a write"
    end
    event = publish

    run_publisher

    expect(event.reload).to have_attributes(correlation_id: nil, attempts: 1)
    expect(consumed(event)).to eq([])
  end

  # ActiveRecord::Rollback ends the consumer's savepoint quietly, taking its
  # consumed_events row along, so it must not count as a delivery.
  it "retries a consumer that rolls back its own transaction" do
    subscribe("goals.prepare") { |_event| raise ActiveRecord::Rollback }
    event = publish

    run_publisher

    expect(event.reload).to have_attributes(attempts: 1, published_at: nil)
    expect(consumed(event)).to eq([])
  end

  it "waits longer after each failure" do
    subscribe("goals.prepare") { |_event| raise "still failing" }
    event = publish
    waits = []

    3.times do
      after_wait(event) do
        run_publisher
        waits << (event.reload.next_attempt_at - Time.current)
      end
    end

    expect(waits).to eq(waits.sort)
    expect(waits.uniq.size).to eq(3)
  end

  it "does not retry before the wait is over" do
    attempts = 0
    subscribe("goals.prepare") do |_event|
      attempts += 1
      raise "failing"
    end
    publish

    2.times { run_publisher }

    expect(attempts).to eq(1)
  end

  it "logs a failure without the error message or the payload" do
    subscribe("goals.prepare") { |_event| raise "failed for ana@example.test" }
    event = publish(payload: { "profile_id" => "profile-secret-id" })
    allow(Rails.logger).to receive(:warn).and_call_original

    run_publisher

    expect(Rails.logger).to have_received(:warn) do |message|
      expect(message).to include(event.id, "user.registered", "goals.prepare", "RuntimeError")
      expect(message).not_to include("ana@example.test")
      expect(message).not_to include("profile-secret-id")
    end
  end

  describe "after 8 attempts" do
    include SentryCapture

    let(:calls) { [] }

    before do
      subscribe("user_profile.create_profile")
      subscribe("goals.prepare") do |event|
        calls << event.id
        raise "failed for ana@example.test"
      end
    end

    def run_until_dead(event)
      8.times { after_wait(event) { run_publisher } }
    end

    it "marks dead after 8 attempts" do
      event = publish

      run_until_dead(event)

      expect(event.reload).to have_attributes(attempts: 8, published_at: nil)
      expect(event.dead_at).to be_present
      expect(calls.size).to eq(8)
      expect(received["user_profile.create_profile"]).to eq([ event.id ])
    end

    it "stops delivering a dead event" do
      event = publish
      run_until_dead(event)

      travel_to(1.day.from_now) { run_publisher }

      expect(calls.size).to eq(8)
    end

    it "alerts with only the event name and the consumer" do
      user_id = SecureRandom.uuid
      event = publish(user_id:, payload: { "profile_id" => "profile-secret-id" })

      run_until_dead(event)

      expect(sentry_events.size).to eq(1)
      alert = sentry_events.first
      expect(alert.exception.values.first.type).to eq("Shared::Outbox::DeadEvent")
      expect(alert.tags).to include(outbox_event: "user.registered", outbox_consumer: "goals.prepare")
      serialized = alert.to_json_compatible.to_json
      [ user_id, event.id, "profile-secret-id", "ana@example.test" ].each { |value| expect(serialized).not_to include(value) }
    end
  end

  describe "discarding" do
    it "drops a matching event without delivering it" do
      user_id = SecureRandom.uuid
      Shared::Outbox.discard_if { |event| event.user_id == user_id }
      subscribe("user_profile.create_profile")
      discarded = publish(user_id:)
      delivered = publish

      run_publisher

      expect(received["user_profile.create_profile"]).to eq([ delivered.id ])
      expect(Shared::Outbox::Event.exists?(discarded.id)).to be(false)
    end

    it "still delivers user.deletion_requested" do
      user_id = SecureRandom.uuid
      Shared::Outbox.discard_if { |event| event.user_id == user_id }
      subscribe("identity.purge", event_name: "user.deletion_requested")
      event = publish(name: "user.deletion_requested", user_id:)

      run_publisher

      expect(received["identity.purge"]).to eq([ event.id ])
    end
  end

  # Committed rows and real threads: the examples above share one transaction,
  # which other connections cannot see.
  describe "two publishers at once" do
    self.use_transactional_tests = false

    after do
      Shared::Outbox::Event.delete_all
    end

    it "delivers once" do
      started = Queue.new
      subscribe("user_profile.create_profile") do |event|
        started << true
        sleep 0.2
        received["user_profile.create_profile"] << event.id
      end
      event = ActiveRecord::Base.transaction { Shared::Outbox.publish!(name: "user.registered", user_id: SecureRandom.uuid) }

      threads = 2.times.map { Thread.new { ActiveRecord::Base.connection_pool.with_connection { run_publisher } } }
      threads.each(&:join)

      expect(received["user_profile.create_profile"]).to eq([ event.id ])
      expect(started.size).to eq(1)
      expect(event.reload.published_at).to be_present
    end

    it "skips an event another publisher holds, instead of waiting for it" do
      subscribe("user_profile.create_profile")
      event = ActiveRecord::Base.transaction { Shared::Outbox.publish!(name: "user.registered", user_id: SecureRandom.uuid) }
      locked = Queue.new
      release = Queue.new
      holder = Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          Shared::Outbox::Event.transaction do
            Shared::Outbox::Event.lock.find(event.id)
            locked << true
            release.pop
          end
        end
      end
      locked.pop

      Timeout.timeout(2) { run_publisher }

      expect(received["user_profile.create_profile"]).to eq([])
    ensure
      release << true
      holder&.join
    end
  end
end

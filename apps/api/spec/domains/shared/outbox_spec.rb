require "rails_helper"
require "support/outbox_helpers"

RSpec.describe Shared::Outbox do
  include OutboxHelpers

  let(:user_id) { SecureRandom.uuid }

  describe ".publish!" do
    it "publishes in the same transaction" do
      ActiveRecord::Base.transaction do
        described_class.publish!(name: "user.registered", user_id:)
        raise ActiveRecord::Rollback
      end

      expect(Shared::Outbox::Event.where(user_id:)).to be_empty
    end

    it "records the event with its envelope" do
      event = publish(name: "user.registered", user_id:, payload: { "profile_id" => user_id })

      expect(event.reload).to have_attributes(
        name: "user.registered", user_id:, version: 1, payload: { "profile_id" => user_id },
        attempts: 0, published_at: nil, dead_at: nil
      )
      expect(event.occurred_at).to be_within(5.seconds).of(Time.current)
    end

    it "refuses publish! outside a transaction" do
      expect { described_class.publish!(name: "user.registered", user_id:) }
        .to raise_error(Shared::Outbox::NotInTransaction)
      expect(Shared::Outbox::Event.where(user_id:)).to be_empty
    end

    it "refuses an event name outside the context.fact format" do
      expect { publish(name: "UserRegistered") }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "accepts identifiers, closed-list values, numbers, booleans, dates and lists of them" do
      payload = {
        "profile_id" => SecureRandom.uuid, "units" => "metric", "count" => 2, "first" => true,
        "local_date" => "2026-11-11", "at" => "2026-11-11T10:00:00Z", "sports" => %w[running cycling], "none" => nil
      }

      expect(publish(payload:).reload.payload).to eq(payload)
    end

    it "accepts an IANA time zone, which has capitals and a slash" do
      payload = { "time_zone" => "America/Sao_Paulo" }

      expect(publish(payload:).reload.payload).to eq(payload)
    end

    [
      [ "an e-mail", { "email" => "ana@example.test" } ],
      [ "a made-up time zone", { "time_zone" => "Marte/Base" } ],
      [ "a path disguised as a time zone", { "time_zone" => "../../etc/passwd" } ],
      [ "a name", { "name" => "Ana" } ],
      [ "free text", { "note" => "comi arroz no almoço" } ],
      [ "a nested object", { "profile" => { "id" => "x" } } ],
      [ "a long value", { "token" => "a" * 65 } ]
    ].each do |description, payload|
      it "refuses #{description} in the payload" do
        expect { publish(payload:) }.to raise_error(Shared::Outbox::InvalidPayload)
      end
    end

    it "does not put the refused value in the error message" do
      expect { publish(payload: { "email" => "ana@example.test" }) }
        .to raise_error(Shared::Outbox::InvalidPayload) { |error| expect(error.message).not_to include("ana@example.test") }
    end

    context "when publishing after commit is enabled" do
      around do |example|
        Rails.configuration.x.outbox_enqueue_after_commit = true
        example.run
      ensure
        Rails.configuration.x.outbox_enqueue_after_commit = false
      end

      it "schedules the publisher once the transaction commits" do
        allow(Shared::Outbox::PublishJob).to receive(:perform_async)

        ActiveRecord::Base.transaction do
          described_class.publish!(name: "user.registered", user_id:)
          expect(Shared::Outbox::PublishJob).not_to have_received(:perform_async)
        end

        expect(Shared::Outbox::PublishJob).to have_received(:perform_async).once
      end

      it "does not schedule the publisher after a rollback" do
        allow(Shared::Outbox::PublishJob).to receive(:perform_async)

        ActiveRecord::Base.transaction do
          described_class.publish!(name: "user.registered", user_id:)
          raise ActiveRecord::Rollback
        end

        expect(Shared::Outbox::PublishJob).not_to have_received(:perform_async)
      end

      # The change is already committed, and the cron delivers the event anyway.
      it "keeps the committed change when the publisher cannot be scheduled" do
        allow(Shared::Outbox::PublishJob).to receive(:perform_async)
          .and_raise(RedisClient::CannotConnectError, "connect to redis://queue-secret-host failed")
        allow(Rails.logger).to receive(:warn).and_call_original

        event = ActiveRecord::Base.transaction { described_class.publish!(name: "user.registered", user_id:) }

        expect(Shared::Outbox::Event.exists?(event.id)).to be(true)
        expect(Rails.logger).to have_received(:warn) do |message|
          expect(message).to include("RedisClient::CannotConnectError")
          expect(message).not_to include("queue-secret-host")
        end
      end
    end

    it "leaves delivery to the spec in the test environment" do
      allow(Shared::Outbox::PublishJob).to receive(:perform_async)

      publish

      expect(Shared::Outbox::PublishJob).not_to have_received(:perform_async)
    end
  end

  describe ".subscribe" do
    it "registers a consumer for an event" do
      described_class.subscribe("user.registered", consumer: "user_profile.create_profile") { |_event| nil }

      expect(described_class.consumers_for("user.registered").map(&:name)).to eq([ "user_profile.create_profile" ])
      expect(described_class.consumers_for("user.deletion_requested")).to eq([])
    end

    it "replaces a consumer subscribed again under the same name, as a code reload does" do
      2.times { described_class.subscribe("user.registered", consumer: "user_profile.create_profile") { |_event| nil } }

      expect(described_class.consumers_for("user.registered").size).to eq(1)
    end

    it "requires a block" do
      expect { described_class.subscribe("user.registered", consumer: "user_profile.create_profile") }
        .to raise_error(ArgumentError)
    end

    it "refuses a consumer name that could not go in an alert as is" do
      expect { described_class.subscribe("user.registered", consumer: "Ana's consumer") { |_event| nil } }
        .to raise_error(ArgumentError)
    end
  end

  describe ".discard_if" do
    it "discards an event when a registered rule matches" do
      described_class.discard_if { |event| event.user_id == user_id }

      expect(described_class.discard?(Shared::Outbox::Event.new(name: "user.registered", user_id:))).to be(true)
      expect(described_class.discard?(Shared::Outbox::Event.new(name: "user.registered", user_id: SecureRandom.uuid))).to be(false)
    end

    it "never discards user.deletion_requested" do
      described_class.discard_if { |_event| true }

      expect(described_class.discard?(Shared::Outbox::Event.new(name: "user.deletion_requested", user_id:))).to be(false)
    end
  end

  describe "data of the user" do
    it "is registered for export and deletion under the shared context" do
      expect(Shared::DataRegistry.registered_tables).to include("outbox_events")
      expect(Shared::DataRegistry.erasers.map(&:first)).to include("shared")
    end

    it "exports nothing, since events hold only identifiers" do
      publish(user_id:)

      expect(Shared::DataRegistry.export(user_id:)).to include("shared" => {})
    end

    it "erases the user's events except user.deletion_requested" do
      other_user = SecureRandom.uuid
      publish(name: "user.registered", user_id:)
      publish(name: "user.registered", user_id: other_user)
      kept = publish(name: "user.deletion_requested", user_id:)

      eraser = Shared::DataRegistry.erasers.to_h.fetch("shared")
      eraser.call(user_id)

      expect(Shared::Outbox::Event.where(user_id:)).to contain_exactly(kept)
      expect(Shared::Outbox::Event.where(user_id: other_user).count).to eq(1)
    end
  end
end

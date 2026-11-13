require "rails_helper"
require "support/outbox_helpers"

# Account deletion (design 4.4): the request revokes every session and records
# the pending contexts, EraseAccountJob walks the registry's erasers, and the
# users row is anonymized last.
RSpec.describe "account deletion", :real_consumers do
  include OutboxHelpers
  include SentryCapture

  let(:api) { Identity::Api }
  let(:password) { "correct horse battery" }
  let(:email) { "ana@example.test" }
  let!(:user_id) do
    api.register(email:, password:, adult_confirmed: true, time_zone: "America/Sao_Paulo", client: "mobile", device_label: "Pixel 8", ip: "203.0.113.7").user_id
  end
  let(:deletion) { Identity::AccountDeletion.find_by!(user_id:) }

  before { allow(Identity::EraseAccountJob).to receive(:perform_async) }

  def request_deletion(password: self.password)
    api.request_deletion(user_id:, password:, ip: "203.0.113.7")
  end

  def erase
    Identity::EraseAccountJob.new.perform(deletion.id)
  end

  def delete_account
    run_publisher
    api.grant_consent(user_id:, purpose: "health_data", version: 1)
    expect(request_deletion).to eq(:scheduled)
    erase
  end

  describe ".request_deletion" do
    it "a wrong or missing password changes nothing" do
      expect(request_deletion(password: "wrong password!")).to eq(:invalid_password)
      expect(request_deletion(password: nil)).to eq(:invalid_password)

      expect(Identity::AccountDeletion.count).to eq(0)
      expect(Shared::Outbox::Event.where(name: "user.deletion_requested").count).to eq(0)
      expect(Identity::Session.where(user_id:, revoked_at: nil).count).to eq(1)
    end

    it "revokes sessions, records the pending contexts and publishes user.deletion_requested at once" do
      expect(request_deletion).to eq(:scheduled)

      expect(Identity::Session.where(user_id:, revoked_at: nil).count).to eq(0)
      expect(deletion).to have_attributes(pending_contexts: match_array(Shared::DataRegistry.contexts), completed_at: nil)
      expect(deletion.requested_at).to be_present
      event = Shared::Outbox::Event.where(name: "user.deletion_requested").sole
      expect(event).to have_attributes(user_id:, payload: {})
      expect(Identity::AuditEvent.where(user_ref: user_id, action: "account_deletion_requested").sole.metadata).to eq({})
      expect(Identity::EraseAccountJob).to have_received(:perform_async).with(deletion.id)
    end

    it "keeps only the UUID, the dates and the pending contexts" do
      request_deletion

      expect(Identity::AccountDeletion.column_names).to match_array(%w[id user_id requested_at pending_contexts completed_at])
    end

    it "asking twice is safe: one deletion, one event" do
      request_deletion

      expect(request_deletion).to eq(:scheduled)
      expect(Identity::AccountDeletion.where(user_id:).count).to eq(1)
      expect(Shared::Outbox::Event.where(name: "user.deletion_requested").count).to eq(1)
    end

    it "the account can no longer sign in, reset or consent while the erasure runs" do
      request_deletion

      expect(api.authenticate(email:, password:, client: "mobile", device_label: nil, ip: nil)).to eq(:invalid)
      expect(api.verify_password(user_id:, password:)).to be(false)
      expect(api.grant_consent(user_id:, purpose: "health_data", version: 1)).to eq(:not_found)
      expect(api.deletion_requested?(user_id:)).to be(true)
    end
  end

  # Committed rows and real threads: the examples above share one transaction,
  # which other connections cannot see.
  context "with two requests at once, on the real database" do
    self.use_transactional_tests = false

    after do
      [ Identity::AccountDeletion, Identity::AuditEvent, Identity::Session, Shared::Outbox::Event, Identity::User ].each(&:delete_all)
    end

    it "starts one deletion and publishes one event" do
      id = user_id
      # Holds each request after the password check, so both pass the check
      # for an existing deletion before either writes.
      allow(Identity::Api).to receive(:verify_password).and_wrap_original { |original, **arguments| original.call(**arguments).tap { sleep 0.3 } }
      results = Array.new(2) do
        Thread.new { ActiveRecord::Base.connection_pool.with_connection { api.request_deletion(user_id: id, password:, ip: nil) } }
      end.map(&:value)

      expect(results).to eq(%i[scheduled scheduled])
      expect(Identity::AccountDeletion.where(user_id: id).count).to eq(1)
      expect(Shared::Outbox::Event.where(user_id: id, name: "user.deletion_requested").count).to eq(1)
    end
  end

  describe "EraseAccountJob" do
    it "user row keeps the UUID without email or password" do
      delete_account

      user = Identity::User.find(user_id)
      expect(user.deleted_at).to be_present
      expect(user.email).not_to eq(email)
      expect(user.email).to end_with(".invalid")
      expect(user.authenticate(password)).to be(false)
      expect(Identity::User.where(email:)).to be_empty
      expect(deletion.reload).to have_attributes(pending_contexts: [], completed_at: be_present)
    end

    it "same email can sign up again" do
      delete_account

      again = api.register(email: " Ana@Example.test ", password:, adult_confirmed: true, time_zone: "America/Sao_Paulo",
                           client: "web", device_label: nil, ip: nil)

      expect(again.ok?).to be(true)
      expect(again.user_id).not_to eq(user_id)
    end

    it "consent and audit rows stay linked to the UUID" do
      run_publisher
      api.grant_consent(user_id:, purpose: "health_data", version: 1)
      consents = Identity::ConsentRecord.where(user_id:).pluck(:id)
      audits = Identity::AuditEvent.where(user_ref: user_id).pluck(:id)
      request_deletion
      erase

      expect(Identity::ConsentRecord.where(user_id:).pluck(:id)).to match_array(consents)
      expect(Identity::AuditEvent.where(user_ref: user_id).pluck(:id)).to include(*audits)
      expect(Identity::AuditEvent.where(user_ref: user_id).pluck(:action)).to include("account_deletion_requested")
      expect(Identity::Session.where(user_id:)).to be_empty
      expect(UserProfile::Api.profile(user_id:)).to be_nil
    end

    it "failing eraser is retried and finished ones are not repeated" do
      calls = Hash.new(0)
      failures = 1
      Shared::DataRegistry.register(context: "planted_counting", tables: %w[planted_counting_rows], exporter: ->(_id) { {} },
                                    eraser: ->(_id) { calls["planted_counting"] += 1 })
      Shared::DataRegistry.register(context: "planted_flaky", tables: %w[planted_flaky_rows], exporter: ->(_id) { {} },
                                    eraser: lambda { |_id|
                                      calls["planted_flaky"] += 1
                                      raise "boom" if (failures -= 1) >= 0
                                    })
      request_deletion

      expect { erase }.to raise_error(Identity::EraseAccountJob::Incomplete)
      expect(deletion.reload.pending_contexts).to eq([ "planted_flaky" ])
      expect(deletion.completed_at).to be_nil
      expect(Identity::User.find(user_id)).to have_attributes(email:, deleted_at: nil)

      erase

      expect(calls).to eq("planted_counting" => 1, "planted_flaky" => 2)
      expect(deletion.reload).to have_attributes(pending_contexts: [], completed_at: be_present)
      expect(Identity::User.find(user_id).deleted_at).to be_present
    end

    it "a finished deletion does nothing when the job runs again" do
      delete_account
      anonymized = Identity::User.find(user_id).email

      erase

      expect(Identity::User.find(user_id).email).to eq(anonymized)
    end

    it "logs only the deletion id, the context and the error class" do
      Shared::DataRegistry.register(context: "planted_flaky", tables: %w[planted_flaky_rows], exporter: ->(_id) { {} },
                                    eraser: ->(_id) { raise "secret ana@example.test" })
      request_deletion
      allow(Rails.logger).to receive(:warn).and_call_original

      expect { erase }.to raise_error(Identity::EraseAccountJob::Incomplete)

      expect(Rails.logger).to have_received(:warn).with(
        "account erasure failed account_deletion_id=#{deletion.id} context=planted_flaky error=RuntimeError"
      )
    end
  end

  describe "late events" do
    it "a late event does not recreate data" do
      delete_account

      publish(name: "user.registered", user_id:, payload: { time_zone: "America/Sao_Paulo" })
      run_publisher

      expect(UserProfile::Api.profile(user_id:)).to be_nil
      expect(Shared::Outbox::Event.where(user_id:).pluck(:name)).to eq([ "user.deletion_requested" ])
    end

    it "an event of an account whose deletion was only requested is discarded too" do
      request_deletion

      run_publisher

      expect(UserProfile::Api.profile(user_id:)).to be_nil
      expect(Shared::Outbox::Event.where(user_id:, name: "user.registered")).to be_empty
    end

    it "never discards user.deletion_requested" do
      request_deletion
      delivered = []
      Shared::Outbox.subscribe("user.deletion_requested", consumer: "planted.revoke_access") { |event| delivered << event.user_id }

      run_publisher

      expect(delivered).to eq([ user_id ])
    end
  end

  describe "DeletionDeadlineJob" do
    it "alert after 24 hours" do
      request_deletion

      travel_to(23.hours.from_now) { Identity::DeletionDeadlineJob.new.perform }
      expect(sentry_events).to be_empty

      travel_to(25.hours.from_now) { Identity::DeletionDeadlineJob.new.perform }
      expect(sentry_events.size).to eq(1)
      alert = sentry_events.first
      expect(alert.exception.values.first.type).to eq("Identity::DeletionDeadlineJob::Overdue")
      expect(alert.tags).to include(account_deletion: deletion.id)
      serialized = alert.to_json_compatible.to_json
      [ email, user_id ].each { |value| expect(serialized).not_to include(value) }
    end

    it "does not alert for a finished deletion" do
      delete_account

      travel_to(25.hours.from_now) { Identity::DeletionDeadlineJob.new.perform }

      expect(sentry_events).to be_empty
    end

    # The safety net for an enqueue lost after the commit.
    it "enqueues the erasure again for every unfinished deletion" do
      request_deletion
      RSpec::Mocks.space.proxy_for(Identity::EraseAccountJob).reset
      allow(Identity::EraseAccountJob).to receive(:perform_async)

      Identity::DeletionDeadlineJob.new.perform

      expect(Identity::EraseAccountJob).to have_received(:perform_async).with(deletion.id).once
    end
  end
end

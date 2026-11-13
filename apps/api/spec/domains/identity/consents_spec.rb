require "rails_helper"

RSpec.describe "Identity::Api consents" do
  include ActiveSupport::Testing::TimeHelpers

  let(:api) { Identity::Api }
  let(:user_id) { register("ana@example.test") }

  def register(email)
    api.register(email:, password: "correct horse battery", adult_confirmed: true, time_zone: "America/Sao_Paulo",
                 client: "mobile", device_label: nil, ip: nil).user_id
  end

  def records(purpose = "food_photo_ai")
    Identity::ConsentRecord.where(user_id:, purpose:).order(:occurred_at)
  end

  it "history keeps every grant and revoke" do
    start = Time.current.change(usec: 0)
    travel_to(start) { api.grant_consent(user_id:, purpose: "food_photo_ai", version: 1) }
    travel_to(start + 1.minute) { api.revoke_consent(user_id:, purpose: "food_photo_ai") }
    travel_to(start + 2.minutes) { api.grant_consent(user_id:, purpose: "food_photo_ai", version: 1) }

    expect(records.map { |record| [ record.action, record.text_version, record.occurred_at ] }).to eq([
      [ "granted", 1, start ], [ "revoked", 1, start + 1.minute ], [ "granted", 1, start + 2.minutes ]
    ])
  end

  it "records the client the consent came from, when given" do
    api.grant_consent(user_id:, purpose: "usage_metrics", version: 1, source: "web")

    expect(records("usage_metrics").sole.source).to eq("web")
  end

  it "keeps the records append-only" do
    api.grant_consent(user_id:, purpose: "usage_metrics", version: 1)

    expect { records("usage_metrics").sole.update!(action: "revoked") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end

  describe "current state" do
    it "current state comes from the latest record" do
      expect(api.consent_granted?(user_id:, purpose: "food_photo_ai")).to be(false)

      api.grant_consent(user_id:, purpose: "food_photo_ai", version: 1)
      expect(api.consent_granted?(user_id:, purpose: "food_photo_ai")).to be(true)

      api.revoke_consent(user_id:, purpose: "food_photo_ai")
      expect(api.consent_granted?(user_id:, purpose: "food_photo_ai")).to be(false)
    end

    it "keeps the order of two records made in the same instant" do
      freeze_time do
        api.grant_consent(user_id:, purpose: "food_photo_ai", version: 1)
        api.revoke_consent(user_id:, purpose: "food_photo_ai")
      end

      expect(api.consent_granted?(user_id:, purpose: "food_photo_ai")).to be(false)
      expect(records.map(&:action)).to eq(%w[granted revoked])
    end

    it "is per person and per purpose" do
      bia = register("bia@example.test")
      api.grant_consent(user_id: bia, purpose: "health_data", version: 1)

      expect(api.consent_granted?(user_id:, purpose: "health_data")).to be(false)
      expect(api.consent_granted?(user_id: bia, purpose: "food_photo_ai")).to be(false)
      expect(api.consent_granted?(user_id: bia, purpose: "health_data")).to be(true)
    end

    it "refuses a purpose outside the closed list" do
      expect { api.consent_granted?(user_id:, purpose: "marketing") }.to raise_error(ArgumentError)
    end

    it "lists every purpose with its state, current version and accepted version" do
      decided_at = Time.current.change(usec: 0)
      travel_to(decided_at - 1.minute) { api.grant_consent(user_id:, purpose: "usage_metrics", version: 1) }
      travel_to(decided_at) do
        api.grant_consent(user_id:, purpose: "health_data", version: 1)
        api.revoke_consent(user_id:, purpose: "usage_metrics")
      end

      consents = api.consents(user_id:).to_h { |consent| [ consent.purpose, consent.to_h.except(:purpose) ] }

      expect(consents).to eq(
        "health_data" => { state: "granted", current_version: 1, accepted_version: 1, decided_at: },
        "food_photo_ai" => { state: "pending", current_version: 1, accepted_version: nil, decided_at: nil },
        "strava_integration" => { state: "pending", current_version: 1, accepted_version: nil, decided_at: nil },
        "usage_metrics" => { state: "revoked", current_version: 1, accepted_version: nil, decided_at: }
      )
    end
  end

  describe ".grant_consent" do
    it "returns the new state of the purpose" do
      result = api.grant_consent(user_id:, purpose: "health_data", version: 1)

      expect(result).to have_attributes(ok?: true, purpose: "health_data", state: "granted", accepted_version: 1)
    end

    it "unknown purpose is rejected by the database" do
      record = Identity::ConsentRecord.new(user_id:, purpose: "marketing", action: "granted", text_version: 1, occurred_at: Time.current)

      expect { record.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /consent_records_purpose_known/)
    end

    it "an unknown action is rejected by the database" do
      record = Identity::ConsentRecord.new(user_id:, purpose: "health_data", action: "paused", text_version: 1, occurred_at: Time.current)

      expect { record.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /consent_records_action_known/)
    end

    it "answers validation_failed for an unknown purpose, and writes nothing" do
      result = api.grant_consent(user_id:, purpose: "marketing", version: 1)

      expect(result).to have_attributes(ok?: false, code: "validation_failed", details: [ { field: "purpose", code: "inclusion" } ])
      expect(Identity::ConsentRecord.count).to eq(0)
    end

    [ "1", nil, 1.0 ].each do |version|
      it "answers validation_failed for a version that is not an integer (#{version.inspect})" do
        result = api.grant_consent(user_id:, purpose: "health_data", version:)

        expect(result).to have_attributes(ok?: false, code: "validation_failed", details: [ { field: "version", code: "not_an_integer" } ])
        expect(Identity::ConsentRecord.count).to eq(0)
      end
    end

    [ 0, 2 ].each do |version|
      it "outdated version is refused (#{version.inspect})" do
        result = api.grant_consent(user_id:, purpose: "health_data", version:)

        expect(result).to have_attributes(ok?: false, code: "outdated_version", details: [ { field: "version", code: "outdated" } ])
        expect(Identity::ConsentRecord.count).to eq(0)
        expect(Shared::Outbox::Event.where(name: "consent.granted")).to be_empty
      end
    end

    it "publishes consent.granted with the purpose and the version only" do
      api.grant_consent(user_id:, purpose: "health_data", version: 1)

      event = Shared::Outbox::Event.find_by!(name: "consent.granted")
      expect(event).to have_attributes(user_id:, payload: { "purpose" => "health_data", "version" => 1 })
    end

    it "records the grant in the audit trail with the purpose only" do
      api.grant_consent(user_id:, purpose: "health_data", version: 1)

      expect(Identity::AuditEvent.find_by!(action: "consent_granted")).to have_attributes(user_ref: user_id, metadata: { "purpose" => "health_data" })
    end

    it "does not record again a purpose already granted with that version" do
      2.times { api.grant_consent(user_id:, purpose: "health_data", version: 1) }

      expect(records("health_data").count).to eq(1)
      expect(Shared::Outbox::Event.where(name: "consent.granted").count).to eq(1)
    end

    it "answers :not_found for a deleted account" do
      Identity::User.find(user_id).update_columns(deleted_at: Time.current)

      expect(api.grant_consent(user_id:, purpose: "health_data", version: 1)).to eq(:not_found)
      expect(Identity::ConsentRecord.count).to eq(0)
    end
  end

  context "with two grants at once, on the real database" do
    self.use_transactional_tests = false

    after do
      [ Identity::ConsentRecord, Identity::AuditEvent, Identity::Session, Shared::Outbox::Event, Identity::User ].each(&:delete_all)
    end

    it "records only one of two concurrent grants of the same purpose" do
      id = user_id
      # Holds each grant after it reads the latest record, so without the lock
      # both would see none and both would write.
      allow(Identity::ConsentRecord).to receive(:latest).and_wrap_original do |original, **arguments|
        original.call(**arguments).tap { sleep 0.3 }
      end

      results = Array.new(2) do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection { api.grant_consent(user_id: id, purpose: "health_data", version: 1) }
        end
      end.map(&:value)

      expect(results.map(&:state)).to eq(%w[granted granted])
      expect(Identity::ConsentRecord.where(user_id: id).count).to eq(1)
      expect(Shared::Outbox::Event.where(name: "consent.granted").count).to eq(1)
    end
  end

  describe ".revoke_consent" do
    it "revokes, publishes consent.revoked and audits it" do
      api.grant_consent(user_id:, purpose: "strava_integration", version: 1)

      expect(api.revoke_consent(user_id:, purpose: "strava_integration")).to be(true)

      expect(records("strava_integration").last).to have_attributes(action: "revoked", text_version: 1)
      expect(Shared::Outbox::Event.find_by!(name: "consent.revoked").payload).to eq("purpose" => "strava_integration", "version" => 1)
      expect(Identity::AuditEvent.find_by!(action: "consent_revoked").metadata).to eq("purpose" => "strava_integration")
    end

    it "revoking health_data answers deletion_required and keeps it" do
      api.grant_consent(user_id:, purpose: "health_data", version: 1)

      result = api.revoke_consent(user_id:, purpose: "health_data")

      expect(result).to have_attributes(ok?: false, code: "deletion_required")
      expect(api.consent_granted?(user_id:, purpose: "health_data")).to be(true)
      expect(records("health_data").count).to eq(1)
      expect(Shared::Outbox::Event.where(name: "consent.revoked")).to be_empty
    end

    it "writes nothing for a purpose that is not granted" do
      expect(api.revoke_consent(user_id:, purpose: "usage_metrics")).to be(true)

      expect(Identity::ConsentRecord.count).to eq(0)
      expect(Shared::Outbox::Event.where(name: "consent.revoked")).to be_empty
    end

    it "answers validation_failed for an unknown purpose" do
      expect(api.revoke_consent(user_id:, purpose: "marketing")).to have_attributes(code: "validation_failed")
    end
  end

  describe "texts" do
    it "texts are served from config/consents" do
      text = api.consent_text(purpose: "food_photo_ai")

      expect(text).to have_attributes(purpose: "food_photo_ai", version: 1)
      expect(text.body).to eq(Rails.root.join("config/consents/food_photo_ai.v1.md").read)
    end

    it "has a text file for the current version of every purpose" do
      api.consents(user_id:).each do |consent|
        expect(Rails.root.join("config/consents/#{consent.purpose}.v#{consent.current_version}.md")).to exist
      end
    end

    it "answers nil for an unknown purpose, without reading other files" do
      expect(api.consent_text(purpose: "../../config/master")).to be_nil
      expect(api.consent_text(purpose: "marketing")).to be_nil
    end

    it "cites the international transfer in food_photo_ai" do
      expect(api.consent_text(purpose: "food_photo_ai").body).to match(/transferência internacional/i)
    end
  end

  describe "data of the user" do
    it "registers consent_records under the identity context" do
      expect(Shared::DataRegistry.registered_tables).to include("consent_records")
    end

    it "exports the person's consent history and nobody else's" do
      bia = register("bia@example.test")
      api.grant_consent(user_id:, purpose: "health_data", version: 1, source: "mobile")
      api.grant_consent(user_id: bia, purpose: "usage_metrics", version: 1)

      exported = Shared::DataRegistry.export(user_id:).fetch("identity")[:consent_records]

      expect(exported.map { |record| record.except(:occurred_at) }).to eq([
        { purpose: "health_data", text_version: 1, action: "granted", source: "mobile" }
      ])
    end

    it "keeps consent records linked to the UUID when the data is erased" do
      api.grant_consent(user_id:, purpose: "health_data", version: 1)

      Shared::DataRegistry.erasers.to_h.fetch("identity").call(user_id)

      expect(records("health_data").count).to eq(1)
    end
  end
end

require "rails_helper"

RSpec.describe Identity::Api do
  include ActiveSupport::Testing::TimeHelpers

  let(:password) { "correct horse battery" }

  def register(email: "ana@example.test", password: self.password, adult_confirmed: true, time_zone: "America/Sao_Paulo", client: "mobile", device_label: "Pixel 8", ip: "203.0.113.7")
    described_class.register(email:, password:, adult_confirmed:, time_zone:, client:, device_label:, ip:)
  end

  def authenticate(email: "ana@example.test", password: self.password, client: "mobile", device_label: "Pixel 8", ip: "203.0.113.7")
    described_class.authenticate(email:, password:, client:, device_label:, ip:)
  end

  def nothing_written
    [ Identity::User, Identity::Session, Identity::AuditEvent, Shared::Outbox::Event ].map(&:count)
  end

  it "tells the known clients, for code that may not read its constants" do
    expect(described_class.client?("web")).to be(true)
    expect(described_class.client?("mobile")).to be(true)
    expect(described_class.client?("desktop")).to be(false)
  end

  describe ".register" do
    it "creates the account and a session, and returns the token" do
      result = register

      expect(result).to be_a(Identity::Api::Result)
      expect(result.ok?).to be(true)
      expect(register(email: "other@example.test", adult_confirmed: false).ok?).to be(false)
      expect(result.session_token).to be_present
      expect(described_class.session_for(token: result.session_token).user_id).to eq(result.user_id)
    end

    it "stores only the token digest" do
      result = register

      session = Identity::Session.sole
      expect(session.token_digest).to eq(OpenSSL::Digest::SHA256.hexdigest(result.session_token))
      expect(Identity::Session.where(token_digest: result.session_token)).to be_empty
    end

    it "uses 32 random bytes for the token" do
      expect(Base64.urlsafe_decode64(register.session_token).bytesize).to eq(32)
    end

    it "publishes user.registered with the time zone and no personal data" do
      result = register

      event = Shared::Outbox::Event.sole
      expect(event).to have_attributes(name: "user.registered", user_id: result.user_id, payload: { "time_zone" => "America/Sao_Paulo" })
    end

    it "records the sign up in the audit trail, with a keyed hash of the IP" do
      result = register

      audit = Identity::AuditEvent.sole
      expect(audit).to have_attributes(user_ref: result.user_id, action: "sign_up", metadata: { "client" => "mobile" })
      expect(audit.ip_hmac).to eq(OpenSSL::HMAC.hexdigest("SHA256", Rails.configuration.x.audit_ip_hmac_key, "203.0.113.7"))
    end

    it "rejects sign up without adult confirmation, and writes nothing" do
      result = register(adult_confirmed: false)

      expect(result).to be_a(Identity::Api::Errors)
      expect(result.code).to eq("validation_failed")
      expect(result.details).to include({ field: "adult_confirmed", code: "required" })
      expect(nothing_written).to eq([ 0, 0, 0, 0 ])
    end

    it "answers email_taken for an existing e-mail, in any case or spacing" do
      register

      result = register(email: " ANA@example.test ")

      expect(result).to have_attributes(code: "email_taken")
      expect(Identity::User.count).to eq(1)
    end

    it "answers email_taken when the unique index catches a race" do
      register
      allow_any_instance_of(Identity::User).to receive(:valid?).and_return(true)

      expect(register).to have_attributes(code: "email_taken")
    end

    [ "Marte/Base", "", nil, 42 ].each do |time_zone|
      it "refuses the time zone #{time_zone.inspect} with invalid_time_zone, and writes nothing" do
        expect(register(time_zone:)).to have_attributes(code: "invalid_time_zone")
        expect(nothing_written).to eq([ 0, 0, 0, 0 ])
      end
    end

    it "refuses a client other than web and mobile" do
      expect(register(client: "desktop").details).to include({ field: "client", code: "inclusion" })
      expect(Identity::User.count).to eq(0)
    end

    it "refuses a short password, naming the field and the reason only" do
      result = register(password: "abc123")

      expect(result.details).to include({ field: "password", code: "too_short" })
      expect(result.to_h.to_s).not_to include("abc123")
    end
  end

  describe ".authenticate" do
    before { register }

    it "opens a new session" do
      result = authenticate(client: "web", device_label: nil)

      expect(result).to be_a(Identity::Api::Result)
      expect(described_class.session_for(token: result.session_token).client).to eq("web")
    end

    it "treats \" Ana@X.com \" as ana@x.com" do
      described_class.revoke_all(user_id: Identity::User.sole.id)
      register(email: "ana@x.com")

      expect(authenticate(email: " Ana@X.com ")).to be_a(Identity::Api::Result)
    end

    it "answers :invalid for a wrong password and for an unknown e-mail" do
      expect(authenticate(password: "wrong password!")).to eq(:invalid)
      expect(authenticate(email: "nobody@example.test")).to eq(:invalid)
    end

    it "answers :invalid for a deleted account" do
      Identity::User.sole.update!(deleted_at: Time.current)

      expect(authenticate).to eq(:invalid)
    end

    it "audit records a failed sign in without the typed email" do
      authenticate(email: "typed@example.test", password: "wrong password!")

      audit = Identity::AuditEvent.where(action: "sign_in_failed").sole
      expect(audit).to have_attributes(user_ref: nil, metadata: {})
      expect(audit.ip_hmac).to be_present
      expect(audit.attributes.values.join(" ")).not_to include("typed", "203.0.113.7")
    end

    it "records a successful sign in for the user" do
      authenticate(client: "web")

      expect(Identity::AuditEvent.where(action: "sign_in").sole).to have_attributes(user_ref: Identity::User.sole.id, metadata: { "client" => "web" })
    end
  end

  describe ".session_for" do
    let!(:token) { register.session_token }

    it "returns nil for an unknown or blank token" do
      expect(described_class.session_for(token: "nope")).to be_nil
      expect(described_class.session_for(token: nil)).to be_nil
    end

    it "returns nil for a revoked session" do
      session = described_class.session_for(token:)
      described_class.revoke_session(user_id: session.user_id, session_id: session.id)

      expect(described_class.session_for(token:)).to be_nil
    end

    it "updates last use and the idle deadline" do
      travel_to(1.day.from_now) do
        described_class.session_for(token:)

        expect(Identity::Session.sole).to have_attributes(last_used_at: be_within(1.second).of(Time.current),
                                                          idle_expires_at: be_within(1.second).of(30.days.from_now))
      end
    end

    describe "idle and absolute expiry" do
      it "ends a session unused for 30 days" do
        travel_to(30.days.from_now + 1.second) do
          expect(described_class.session_for(token:)).to be_nil
        end
      end

      it "keeps a session used every 29 days, until 90 days from its start" do
        start = Time.current
        [ 29, 58, 87 ].each do |day|
          travel_to(start + day.days) { expect(described_class.session_for(token:)).to be_present }
        end

        travel_to(start + 90.days + 1.second) { expect(described_class.session_for(token:)).to be_nil }
      end

      it "never pushes the idle deadline past the absolute one" do
        start = Time.current
        [ 29, 58, 87 ].each { |day| travel_to(start + day.days) { described_class.session_for(token:) } }

        session = Identity::Session.sole
        expect(session.idle_expires_at).to eq(session.absolute_expires_at)
      end
    end
  end

  describe ".refresh" do
    let!(:token) { register.session_token }

    it "swaps the token, revoking the old one" do
      result = described_class.refresh(token:)

      expect(result.session_token).not_to eq(token)
      expect(described_class.session_for(token:)).to be_nil
      expect(described_class.session_for(token: result.session_token)).to be_present
    end

    it "keeps the absolute deadline of the original session" do
      absolute = Identity::Session.sole.absolute_expires_at

      travel_to(10.days.from_now) do
        new_token = described_class.refresh(token:).session_token

        expect(Identity::Session.find_by(token_digest: OpenSSL::Digest::SHA256.hexdigest(new_token)).absolute_expires_at).to eq(absolute)
      end
    end

    it "returns nil for a revoked or expired token" do
      expect(described_class.refresh(token: "nope")).to be_nil

      travel_to(31.days.from_now) { expect(described_class.refresh(token:)).to be_nil }
    end

    it "returns nil when the same token is refreshed twice" do
      described_class.refresh(token:)

      expect(described_class.refresh(token:)).to be_nil
    end
  end

  describe "sessions of a user" do
    let!(:ana) { register }
    let!(:ana_web) { authenticate(client: "web", device_label: nil) }
    let!(:bia) { register(email: "bia@example.test", device_label: "iPhone") }

    it "lists only the user's own active sessions" do
      described_class.revoke_session(user_id: ana.user_id, session_id: described_class.session_for(token: ana_web.session_token).id)

      sessions = described_class.sessions(user_id: ana.user_id)

      expect(sessions).to all(be_a(Identity::Api::SessionInfo))
      expect(sessions.map(&:client)).to eq([ "mobile" ])
      expect(sessions.map(&:user_id)).to eq([ ana.user_id ])
    end

    it "answers :not_found for another person's session" do
      bia_session = described_class.session_for(token: bia.session_token)

      expect(described_class.revoke_session(user_id: ana.user_id, session_id: bia_session.id)).to eq(:not_found)
      expect(described_class.session_for(token: bia.session_token)).to be_present
    end

    it "answers :not_found for an id that is not a UUID" do
      expect(described_class.revoke_session(user_id: ana.user_id, session_id: "abc")).to eq(:not_found)
    end

    it "revokes one session and records it" do
      session = described_class.session_for(token: ana.session_token)

      expect(described_class.revoke_session(user_id: ana.user_id, session_id: session.id)).to be(true)
      expect(Identity::AuditEvent.where(action: "session_revoked", user_ref: ana.user_id).count).to eq(1)
    end

    it "revokes all sessions of the user only" do
      described_class.revoke_all(user_id: ana.user_id)

      expect(described_class.sessions(user_id: ana.user_id)).to eq([])
      expect(described_class.sessions(user_id: bia.user_id).size).to eq(1)
    end
  end

  describe ".verify_password" do
    let!(:user_id) { register.user_id }

    it "confirms only the right password" do
      expect(described_class.verify_password(user_id:, password:)).to be(true)
      expect(described_class.verify_password(user_id:, password: "wrong password!")).to be(false)
      expect(described_class.verify_password(user_id: SecureRandom.uuid, password:)).to be(false)
    end
  end

  describe ".normalize_email" do
    it "normalizes as the account does, so limits and lookups agree" do
      expect(described_class.normalize_email(" Ana@X.com ")).to eq("ana@x.com")
      expect(described_class.normalize_email(nil)).to eq("")
      expect(described_class.normalize_email(Identity::User.normalize_value_for(:email, " B@Y.com"))).to eq("b@y.com")
    end
  end

  describe ".request_password_reset" do
    let!(:user_id) { register.user_id }

    before { allow(Identity::PasswordResetJob).to receive(:perform_async) }

    it "returns nil whether the account exists or not" do
      expect(described_class.request_password_reset(email: " ANA@example.test")).to be_nil
      expect(described_class.request_password_reset(email: "nobody@example.test")).to be_nil
      expect(described_class.request_password_reset(email: nil)).to be_nil

      expect(Identity::PasswordResetJob).to have_received(:perform_async).with(user_id).once
      expect(Identity::PasswordResetJob).to have_received(:perform_async).with(nil).twice
    end

    it "writes nothing" do
      expect { described_class.request_password_reset(email: "ana@example.test") }.not_to(change { nothing_written })
    end
  end

  describe ".reset_password" do
    let!(:user_id) { register.user_id }
    let(:token) { Identity::User.find(user_id).password_reset_token }
    let(:new_password) { "a brand new passphrase" }

    it "changes the password once and revokes every session" do
      authenticate

      expect(described_class.reset_password(token:, password: new_password, ip: "203.0.113.7")).to be(true)

      expect(described_class.verify_password(user_id:, password: new_password)).to be(true)
      expect(Identity::Session.where(user_id:, revoked_at: nil)).to be_empty
      expect(described_class.reset_password(token:, password: "yet another passphrase")).to eq(:invalid)
    end

    it "answers :invalid for anything that is not a valid token" do
      [ nil, "", "garbage", [ token ], { token: } ].each do |value|
        expect(described_class.reset_password(token: value, password: new_password)).to eq(:invalid)
      end
    end

    it "answers :invalid for the account of a deleted user" do
      issued = token
      Identity::User.find(user_id).update_columns(deleted_at: Time.current)

      expect(described_class.reset_password(token: issued, password: new_password)).to eq(:invalid)
    end

    it "refuses a weak password with the field and the reason, never the value" do
      result = described_class.reset_password(token:, password: "short")

      expect(result).to have_attributes(ok?: false, code: "validation_failed", details: [ { field: "password", code: "too_short" } ])
      [ nil, "", 123 ].each do |value|
        expect(described_class.reset_password(token:, password: value)).to have_attributes(code: "validation_failed", details: [ { field: "password", code: "blank" } ])
      end
      expect(described_class.verify_password(user_id:, password:)).to be(true)
      expect(Identity::Session.where(user_id:, revoked_at: nil).count).to eq(1)
    end
  end

  describe "data of the user" do
    let!(:ana) { register }
    let!(:bia) { register(email: "bia@example.test") }

    it "registers users, sessions and audit_events under the identity context" do
      expect(Shared::DataRegistry.registered_tables).to include("users", "sessions", "audit_events")
    end

    it "exports the user's own rows, without secrets" do
      exported = Shared::DataRegistry.export(user_id: ana.user_id).fetch("identity")

      expect(exported[:user]).to include(id: ana.user_id, email: "ana@example.test")
      expect(exported[:sessions].map { |session| session[:client] }).to eq([ "mobile" ])
      expect(exported[:audit_events].map { |audit| audit[:action] }).to eq([ "sign_up" ])
      text = exported.to_s
      expect(text).not_to include("bia@example.test", "password_digest", "token_digest", "ip_hmac", ana.session_token)
    end

    it "erases the user's sessions and keeps the account row and audit trail for the deletion flow" do
      eraser = Shared::DataRegistry.erasers.to_h.fetch("identity")

      2.times { eraser.call(ana.user_id) }

      expect(Identity::Session.where(user_id: ana.user_id)).to be_empty
      expect(Identity::Session.where(user_id: bia.user_id).count).to eq(1)
      expect(Identity::User.where(id: ana.user_id)).to exist
      expect(Identity::AuditEvent.where(user_ref: ana.user_id)).to exist
    end
  end
end

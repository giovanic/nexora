require "rails_helper"

# Daily retention (DATABASE_DESIGN.md, "Retenção"). Periods are provisional,
# pending legal review. Only Identity's own tables are touched here.
RSpec.describe Identity::RetentionJob do
  include ActiveSupport::Testing::TimeHelpers

  let(:now) { Time.zone.local(2026, 11, 13, 12) }
  let(:user) { create_user("ana@example.test") }

  around { |example| travel_to(now) { example.run } }

  def create_user(email, deleted_at: nil)
    Identity::User.create!(email:, password_digest: "x", adult_confirmed_at: now, deleted_at:)
  end

  def session_for(user, idle: now + 10.days, absolute: now + 60.days, revoked_at: nil)
    Identity::Session.create!(user:, token_digest: SecureRandom.hex(16), client: "mobile", last_used_at: now,
                              idle_expires_at: idle, absolute_expires_at: absolute, revoked_at:)
  end

  def consent(user, purpose, action, at)
    Identity::ConsentRecord.create!(user_id: user.id, purpose:, text_version: 1, action:, source: "mobile", occurred_at: at)
  end

  def audit(at)
    Identity::AuditEvent.create!(user_ref: user.id, action: "sign_in", metadata: {}, occurred_at: at)
  end

  it "retention removes what is past its period and keeps the rest" do
    kept_sessions = [
      session_for(user),
      session_for(user, idle: now - 29.days, absolute: now + 10.days),
      session_for(user, revoked_at: now - 29.days)
    ]
    removed_sessions = [
      session_for(user, idle: now - 31.days, absolute: now + 10.days),
      session_for(user, idle: now - 32.days, absolute: now - 31.days),
      session_for(user, revoked_at: now - 31.days)
    ]
    kept_audit = [ audit(now - 5.years + 1.day), audit(now) ]
    removed_audit = [ audit(now - 5.years - 1.day) ]
    old_grant = consent(user, "usage_metrics", "granted", now - 6.years)
    old_revoke = consent(user, "usage_metrics", "revoked", now - 5.years - 1.day)
    current = consent(user, "health_data", "granted", now - 6.years)
    recent = consent(user, "food_photo_ai", "granted", now - 1.year)
    gone = create_user("gone@example.test", deleted_at: now - 6.years)
    gone_record = consent(gone, "health_data", "granted", now - 6.years)
    completed = Identity::AccountDeletion.create!(user_id: gone.id, requested_at: now - 40.days, completed_at: now - 40.days, pending_contexts: [])

    result = described_class.new.perform

    expect(Identity::Session.where(id: kept_sessions)).to match_array(kept_sessions)
    expect(Identity::Session.where(id: removed_sessions)).to be_empty
    expect(Identity::AuditEvent.where(id: kept_audit)).to match_array(kept_audit)
    expect(Identity::AuditEvent.where(id: removed_audit)).to be_empty
    expect(Identity::ConsentRecord.where(id: [ old_grant, old_revoke, current, recent, gone_record ])).to match_array([ old_revoke, current, recent ])
    expect(Identity::AccountDeletion.find(completed.id)).to have_attributes(user_id: gone.id, pending_contexts: [])
    expect(result).to eq(sessions: 3, audit_events: 1, consent_records: 2)
  end

  it "keeps the latest consent of a live account, the proof of what it holds today" do
    only = consent(user, "health_data", "granted", now - 8.years)

    described_class.new.perform

    expect(Identity::ConsentRecord.find(only.id)).to be_present
  end

  it "is idempotent" do
    session_for(user, revoked_at: now - 31.days)
    audit(now - 6.years)

    described_class.new.perform

    expect(described_class.new.perform).to eq(sessions: 0, audit_events: 0, consent_records: 0)
  end

  it "deletes in batches" do
    stub_const("#{described_class}::BATCH", 2)
    5.times { session_for(user, revoked_at: now - 31.days) }
    deletes = []
    callback = ->(*, payload) { deletes << payload[:sql] if payload[:sql].start_with?("DELETE FROM \"sessions\"") }

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      expect(described_class.new.perform).to include(sessions: 5)
    end

    expect(deletes.size).to eq(3)
  end

  it "never logs more than counts" do
    session_for(user, revoked_at: now - 31.days)
    io = StringIO.new
    allow(Sidekiq).to receive(:logger).and_return(Logger.new(io))

    described_class.new.perform

    expect(io.string).not_to include(user.id, "ana@example.test")
  end
end

require "rails_helper"
require "support/outbox_helpers"

# A write that passed the controller's consent gate just before the revoke
# committed must not leave health data behind. Committed rows and real threads.
RSpec.describe "health_data revoked during a profile write", :real_consumers do
  include OutboxHelpers

  self.use_transactional_tests = false

  let(:api) { UserProfile::Api }
  let!(:user_id) do
    Identity::Api.register(email: "ana@example.test", password: "correct horse battery", adult_confirmed: true,
                           time_zone: "America/Sao_Paulo", client: "mobile", device_label: nil, ip: nil).user_id
  end

  before do
    Identity::Api.grant_consent(user_id:, purpose: "health_data", version: 1)
    run_publisher
    api.set_sport(user_id:, sport: "running", level: "beginner")
  end

  after do
    ActiveRecord::Base.connection.execute("TRUNCATE users, outbox_events CASCADE")
  end

  def revoke_and_erase
    Identity::Api.revoke_consent(user_id:, purpose: "health_data")
    run_publisher
  end

  def health_data_left?
    profile = UserProfile::Profile.find(user_id)
    UserProfile::SportProfile.where(user_id:).exists? || profile.display_name.present? || profile.motivations.any?
  end

  # The write is already past the gate: it calls the Api as the controller would.
  it "refuses a profile update after the revoke, and leaves nothing" do
    revoke_and_erase

    expect(api.update_profile(user_id:, attrs: { display_name: "Ana", motivations: %w[start_caring] })).to eq(:consent_required)
    expect(health_data_left?).to be(false)
  end

  it "refuses a sport change and a removal after the revoke" do
    sport_id = UserProfile::SportProfile.sole.id
    revoke_and_erase

    expect(api.set_sport(user_id:, sport: "cycling", level: "advanced")).to eq(:consent_required)
    expect(api.remove_sport(user_id:, sport_id:)).to eq(:consent_required)
    expect(health_data_left?).to be(false)
  end

  it "a write waiting on the profile lock sees the revoke that commits first" do
    result = nil
    UserProfile::Profile.transaction do
      UserProfile::Profile.lock.find(user_id)
      writer = Thread.new { ActiveRecord::Base.connection_pool.with_connection { api.update_profile(user_id:, attrs: { display_name: "Ana" }) } }
      sleep 0.3
      Identity::Api.revoke_consent(user_id:, purpose: "health_data")
      @writer = writer
    end
    result = @writer.value
    run_publisher

    expect(result).to eq(:consent_required)
    expect(health_data_left?).to be(false)
  end

  it "a write that commits before the consumer is erased by it" do
    api.update_profile(user_id:, attrs: { display_name: "Ana" })
    revoke_and_erase

    expect(health_data_left?).to be(false)
  end

  it "does not erase data written after the person granted the consent again" do
    Identity::Api.revoke_consent(user_id:, purpose: "health_data")
    Identity::Api.grant_consent(user_id:, purpose: "health_data", version: 1)
    api.set_sport(user_id:, sport: "cycling", level: "advanced")
    run_publisher

    expect(UserProfile::SportProfile.where(user_id:, sport: "cycling")).to exist
  end

  it "still erases when the consent stays revoked after a grant and a later revoke" do
    Identity::Api.revoke_consent(user_id:, purpose: "health_data")
    Identity::Api.grant_consent(user_id:, purpose: "health_data", version: 1)
    Identity::Api.revoke_consent(user_id:, purpose: "health_data")
    run_publisher

    expect(health_data_left?).to be(false)
  end
end

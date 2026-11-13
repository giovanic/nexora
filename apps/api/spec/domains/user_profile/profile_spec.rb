require "rails_helper"
require "support/outbox_helpers"

RSpec.describe "UserProfile::Api", :real_consumers do
  include OutboxHelpers

  let(:api) { UserProfile::Api }
  let(:user_id) do
    Identity::Api.register(email: "ana@example.test", password: "correct horse battery", adult_confirmed: true,
                           time_zone: "America/Sao_Paulo", client: "mobile", device_label: nil, ip: nil).user_id
  end

  # The profile exists once the user.registered consumer has run.
  def deliver
    run_publisher
  end

  before do
    user_id
    deliver
  end

  def codes(result) = result.details.map { |detail| [ detail[:field], detail[:code] ] }

  describe "creation on user.registered" do
    it "profile is created on user.registered, once" do
      expect(api.profile(user_id:)).to have_attributes(time_zone: "America/Sao_Paulo", units: "metric", motivations: [], display_name: nil)

      event = Shared::Outbox::Event.find_by!(name: "user.registered", user_id:)
      expect { event.update!(published_at: nil) && run_publisher }.not_to change(UserProfile::Profile, :count)
      Shared::Outbox.consumers_for("user.registered").each { |consumer| consumer.handler.call(event) }
      expect(UserProfile::Profile.where(user_id:).count).to eq(1)
    end

    it "answers nil until the consumer has run" do
      other = Identity::Api.register(email: "bia@example.test", password: "correct horse battery", adult_confirmed: true,
                                     time_zone: "UTC", client: "mobile", device_label: nil, ip: nil).user_id

      expect(api.profile(user_id: other)).to be_nil
      expect(api.update_profile(user_id: other, attrs: { display_name: "Bia" })).to eq(:pending)
      expect(api.set_sport(user_id: other, sport: "running", level: "beginner")).to eq(:pending)
    end
  end

  describe "update_profile" do
    it "saves the display name, motivations and time zone" do
      result = api.update_profile(user_id:, attrs: { display_name: "Ana", time_zone: "Europe/Lisbon", motivations: %w[start_caring track_progress] })

      expect(result).to have_attributes(display_name: "Ana", time_zone: "Europe/Lisbon", motivations: %w[start_caring track_progress])
      expect(api.time_zone(user_id:)).to eq("Europe/Lisbon")
    end

    it "only changes the fields sent" do
      api.update_profile(user_id:, attrs: { display_name: "Ana", motivations: %w[start_caring] })

      api.update_profile(user_id:, attrs: { display_name: nil })

      expect(api.profile(user_id:)).to have_attributes(display_name: nil, motivations: %w[start_caring])
    end

    it "invalid time zone is 422 and nothing is saved" do
      result = api.update_profile(user_id:, attrs: { display_name: "Ana", time_zone: "Marte/Base" })

      expect(result).to have_attributes(code: "invalid_time_zone")
      expect(api.profile(user_id:)).to have_attributes(display_name: nil, time_zone: "America/Sao_Paulo")
    end

    it "motivations outside the list are refused" do
      result = api.update_profile(user_id:, attrs: { motivations: %w[start_caring lose_weight] })

      expect(codes(result)).to eq([ [ "motivations", "inclusion" ] ])
      expect(api.profile(user_id:).motivations).to eq([])
    end

    it "more than 4 motivations are refused" do
      five = %w[start_caring training_consistency understand_food track_progress start_caring]

      result = api.update_profile(user_id:, attrs: { motivations: five })

      expect(codes(result)).to eq([ [ "motivations", "too_long" ] ])
      expect(api.profile(user_id:).motivations).to eq([])
    end

    it "refuses motivations that are not a list" do
      expect(codes(api.update_profile(user_id:, attrs: { motivations: "start_caring" })))
        .to eq([ [ "motivations", "invalid" ] ])
    end

    it "refuses a display name that is too long or not text" do
      expect(codes(api.update_profile(user_id:, attrs: { display_name: "a" * 61 }))).to eq([ [ "display_name", "too_long" ] ])
      expect(codes(api.update_profile(user_id:, attrs: { display_name: 12 }))).to eq([ [ "display_name", "invalid" ] ])
    end

    it "display_name is encrypted at rest" do
      api.update_profile(user_id:, attrs: { display_name: "Ana Souza" })

      raw = ActiveRecord::Base.connection.select_value("SELECT display_name FROM user_profiles WHERE user_id = '#{user_id}'")

      expect(raw).to be_present.and(satisfy { |value| !value.include?("Ana") })
      expect(UserProfile::Profile.find(user_id).display_name).to eq("Ana Souza")
    end

    it "encrypts the same name differently each time" do
      api.update_profile(user_id:, attrs: { display_name: "Ana" })
      first = ActiveRecord::Base.connection.select_value("SELECT display_name FROM user_profiles")
      UserProfile::Profile.find(user_id).update!(display_name: "Bia")
      UserProfile::Profile.find(user_id).update!(display_name: "Ana")

      expect(ActiveRecord::Base.connection.select_value("SELECT display_name FROM user_profiles")).not_to eq(first)
    end
  end

  describe "sports" do
    def events = Shared::Outbox::Event.where(name: "sport_profile.changed", user_id:).order(:occurred_at)

    it "adds a sport and lists it" do
      api.set_sport(user_id:, sport: "running", level: "beginner")

      expect(api.sports(user_id:).map { |sport| [ sport.sport, sport.level ] }).to eq([ %w[running beginner] ])
    end

    it "changing a level ends the current row and starts a new one" do
      first = api.set_sport(user_id:, sport: "running", level: "beginner")

      second = api.set_sport(user_id:, sport: "running", level: "intermediate")

      expect(second.id).not_to eq(first.id)
      expect(UserProfile::SportProfile.find(first.id).ended_at).to be_present
      expect(UserProfile::SportProfile.find(second.id)).to have_attributes(level: "intermediate", ended_at: nil)
      expect(api.sports(user_id:).map(&:id)).to eq([ second.id ])
    end

    it "history survives a level change" do
      start = Time.current.change(usec: 0)
      travel_to(start) { api.set_sport(user_id:, sport: "running", level: "beginner") }
      travel_to(start + 1.day) { api.set_sport(user_id:, sport: "running", level: "intermediate") }
      travel_to(start + 2.days) { api.set_sport(user_id:, sport: "running", level: "advanced") }

      rows = UserProfile::SportProfile.where(user_id:, sport: "running").order(:started_at)

      expect(rows.map { |row| [ row.level, row.started_at, row.ended_at ] }).to eq([
        [ "beginner", start, start + 1.day ], [ "intermediate", start + 1.day, start + 2.days ], [ "advanced", start + 2.days, nil ]
      ])
      expect(api.sports(user_id:, include_history: true).map(&:level)).to eq(%w[beginner intermediate advanced])
    end

    it "does nothing when the level is the same" do
      first = api.set_sport(user_id:, sport: "cycling", level: "advanced")

      expect(api.set_sport(user_id:, sport: "cycling", level: "advanced").id).to eq(first.id)
      expect(UserProfile::SportProfile.where(user_id:).count).to eq(1)
      expect(events.count).to eq(1)
    end

    it "refuses a sport or level outside the lists" do
      expect(codes(api.set_sport(user_id:, sport: "chess", level: "beginner"))).to eq([ [ "sport", "inclusion" ] ])
      expect(codes(api.set_sport(user_id:, sport: "running", level: "pro"))).to eq([ [ "level", "inclusion" ] ])
      expect(UserProfile::SportProfile.count).to eq(0)
    end

    it "keeps one active row per sport at the database" do
      api.set_sport(user_id:, sport: "running", level: "beginner")

      expect { UserProfile::SportProfile.insert!({ user_id:, sport: "running", level: "advanced", started_at: Time.current }) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "removing a sport ends the row and keeps it as history" do
      sport = api.set_sport(user_id:, sport: "swimming", level: "beginner")

      expect(api.remove_sport(user_id:, sport_id: sport.id)).to eq(true)

      expect(api.sports(user_id:)).to eq([])
      expect(UserProfile::SportProfile.find(sport.id).ended_at).to be_present
      expect(api.remove_sport(user_id:, sport_id: sport.id)).to eq(:not_found)
    end

    it "does not remove another person's sport" do
      sport = api.set_sport(user_id:, sport: "swimming", level: "beginner")
      other = Identity::Api.register(email: "bia@example.test", password: "correct horse battery", adult_confirmed: true,
                                     time_zone: "UTC", client: "mobile", device_label: nil, ip: nil).user_id
      deliver

      expect(api.remove_sport(user_id: other, sport_id: sport.id)).to eq(:not_found)
      expect(api.remove_sport(user_id:, sport_id: "not-a-uuid")).to eq(:not_found)
      expect(api.sports(user_id:).size).to eq(1)
    end

    it "publishes sport_profile.changed with identifiers and closed-list values only" do
      first = api.set_sport(user_id:, sport: "running", level: "beginner")
      api.set_sport(user_id:, sport: "running", level: "advanced")
      api.remove_sport(user_id:, sport_id: api.sports(user_id:).sole.id)

      expect(events.map(&:payload)).to match([
        { "sport_profile_id" => first.id, "sport" => "running", "level" => "beginner", "change" => "added" },
        { "sport_profile_id" => kind_of(String), "sport" => "running", "level" => "advanced", "change" => "level_changed" },
        { "sport_profile_id" => kind_of(String), "sport" => "running", "level" => "advanced", "change" => "removed" }
      ])
    end

    it "publishes nothing for a refused change" do
      api.set_sport(user_id:, sport: "chess", level: "beginner")

      expect(events.count).to eq(0)
    end
  end

  describe "data registry" do
    it "registers both tables, exports and erases" do
      api.update_profile(user_id:, attrs: { display_name: "Ana", motivations: %w[understand_food] })
      api.set_sport(user_id:, sport: "running", level: "beginner")
      api.set_sport(user_id:, sport: "running", level: "advanced")

      expect(Shared::DataRegistry.registered_tables).to include("user_profiles", "sport_profiles")
      exported = Shared::DataRegistry.export(user_id:).fetch("user_profile")
      expect(exported.fetch(:profile)).to include(display_name: "Ana", motivations: %w[understand_food], time_zone: "America/Sao_Paulo")
      expect(exported.fetch(:sport_profiles).map { |row| row[:level] }).to eq(%w[beginner advanced])

      Shared::DataRegistry.erasers.to_h.fetch("user_profile").call(user_id)
      Shared::DataRegistry.erasers.to_h.fetch("user_profile").call(user_id)

      expect(UserProfile::Profile.where(user_id:)).to be_empty
      expect(UserProfile::SportProfile.where(user_id:)).to be_empty
    end
  end

  describe "erasure on consent.revoked" do
    let(:other_id) do
      Identity::Api.register(email: "bia@example.test", password: "correct horse battery", adult_confirmed: true,
                             time_zone: "UTC", client: "mobile", device_label: nil, ip: nil).user_id
    end

    def revoke(purpose, who = user_id, version: 1)
      ActiveRecord::Base.transaction { Shared::Outbox.publish!(name: "consent.revoked", user_id: who, payload: { purpose:, version: }) }
      run_publisher
    end

    before do
      other_id
      deliver
      [ user_id, other_id ].each do |id|
        api.update_profile(user_id: id, attrs: { display_name: "Nome", motivations: %w[start_caring], time_zone: "Europe/Lisbon" })
        api.set_sport(user_id: id, sport: "running", level: "beginner")
        api.set_sport(user_id: id, sport: "running", level: "advanced")
      end
    end

    it "health_data erases sports with history, motivations and name, keeping time zone and units" do
      revoke("health_data")

      expect(UserProfile::SportProfile.where(user_id:)).to be_empty
      expect(api.profile(user_id:)).to have_attributes(display_name: nil, motivations: [], time_zone: "Europe/Lisbon", units: "metric")
    end

    it "never touches another person" do
      revoke("health_data")

      expect(UserProfile::SportProfile.where(user_id: other_id).count).to eq(2)
      expect(api.profile(user_id: other_id)).to have_attributes(display_name: "Nome", motivations: %w[start_caring])
    end

    it "ignores other purposes" do
      revoke("strava_integration")
      revoke("usage_metrics")

      expect(UserProfile::SportProfile.where(user_id:).count).to eq(2)
      expect(api.profile(user_id:)).to have_attributes(display_name: "Nome", motivations: %w[start_caring])
    end

    it "is safe to deliver again" do
      revoke("health_data")
      event = Shared::Outbox::Event.find_by!(name: "consent.revoked", user_id:)

      expect { Shared::Outbox.consumers_for("consent.revoked").each { |consumer| consumer.handler.call(event) } }.not_to raise_error
      expect(UserProfile::SportProfile.where(user_id:)).to be_empty
    end

    it "does nothing for a person without a profile" do
      ghost = SecureRandom.uuid

      expect { revoke("health_data", ghost) }.not_to change(UserProfile::Profile, :count)
    end
  end
end

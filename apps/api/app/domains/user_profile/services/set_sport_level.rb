module UserProfile
  # Sets the level of a sport, or ends it. Changing a level ends the active row
  # and starts another, so the history is never rewritten. The profile row is
  # locked, which puts one person's changes in a row, and health_data is checked under that lock.
  module SetSportLevel
    def self.call(user_id:, sport:, level:)
      invalid = { "sport" => [ sport, SportProfile::SPORTS ], "level" => [ level, SportProfile::LEVELS ] }
                .reject { |_field, (value, allowed)| allowed.include?(value) }
                .map { |field, _| { field:, code: "inclusion" } }
      return Api::Errors.new(code: "validation_failed", details: invalid) if invalid.any?

      LockedProfile.call(user_id:) do
        current = SportProfile.active.find_by(user_id:, sport:)
        next Api.present_sport(current) if current&.level == level

        now = Time.current
        current&.update!(ended_at: now)
        created = SportProfile.create!(user_id:, sport:, level:, started_at: now)
        publish(created, current ? "level_changed" : "added")
        Api.present_sport(created)
      end
    end

    def self.remove(user_id:, sport_id:)
      LockedProfile.call(user_id:) do
        sport = SportProfile.active.find_by(user_id:, id: sport_id) if sport_id.to_s.match?(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/)
        next :not_found unless sport

        sport.update!(ended_at: Time.current)
        publish(sport, "removed")
        true
      end
    end

    # Identifier and kind of change only: sport and level are health data, which
    # an event outlives (ruling R3). Consumers read them through UserProfile::Api.
    def self.publish(sport, change)
      Shared::Outbox.publish!(name: "sport_profile.changed", user_id: sport.user_id,
                              payload: { sport_profile_id: sport.id, change: })
    end

    private_class_method :publish
  end
end

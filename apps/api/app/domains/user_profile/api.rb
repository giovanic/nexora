module UserProfile
  # The only entry point to UserProfile for other contexts and controllers. It
  # returns Data objects, never models.
  module Api
    USER_DATA_TABLES = %w[user_profiles sport_profiles].freeze
    ProfileInfo = Data.define(:user_id, :display_name, :time_zone, :units, :motivations) do
      def ok? = true
    end
    SportInfo = Data.define(:id, :sport, :level, :started_at, :ended_at) do
      def ok? = true
    end
    # details: [{ field:, code: }], never the submitted values.
    Errors = Data.define(:code, :details) do
      def ok? = false
    end

    class << self
      # nil until the user.registered consumer has created it.
      def profile(user_id:)
        profile = Profile.find_by(user_id:)
        present(profile) if profile
      end

      # ProfileInfo, Errors (invalid_time_zone, validation_failed) or :pending.
      def update_profile(user_id:, attrs:)
        UpdateProfile.call(user_id:, attrs:)
      end

      def time_zone(user_id:)
        Profile.where(user_id:).pick(:time_zone)
      end

      # Active sports, or every period (the history) with include_history.
      def sports(user_id:, include_history: false)
        scope = include_history ? SportProfile.all : SportProfile.active
        scope.where(user_id:).order(:started_at, :id).map { |sport| present_sport(sport) }
      end

      # SportInfo, Errors (validation_failed) or :pending.
      def set_sport(user_id:, sport:, level:)
        SetSportLevel.call(user_id:, sport:, level:)
      end

      # true, :not_found (also for another person's id) or :pending.
      def remove_sport(user_id:, sport_id:)
        SetSportLevel.remove(user_id:, sport_id:)
      end

      def export_user_data(user_id)
        UserData.export(user_id)
      end

      def erase_user_data(user_id)
        UserData.erase(user_id)
      end

      def present(profile)
        ProfileInfo.new(user_id: profile.user_id, display_name: profile.display_name, time_zone: profile.time_zone,
                        units: profile.units, motivations: profile.motivations)
      end

      def present_sport(sport)
        SportInfo.new(id: sport.id, sport: sport.sport, level: sport.level, started_at: sport.started_at, ended_at: sport.ended_at)
      end
    end
  end
end

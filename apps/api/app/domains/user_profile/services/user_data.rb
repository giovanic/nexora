module UserProfile
  # UserProfile's part of account export and deletion, through Shared::DataRegistry.
  module UserData
    def self.export(user_id)
      profile = Profile.find_by(user_id:)
      {
        profile: profile && profile.slice(:display_name, :time_zone, :units, :notification_preferences, :motivations, :created_at, :updated_at).symbolize_keys,
        sport_profiles: SportProfile.where(user_id:).order(:started_at).map do |sport|
          sport.slice(:id, :sport, :level, :started_at, :ended_at).symbolize_keys
        end
      }
    end

    # Safe to run again.
    def self.erase(user_id)
      SportProfile.where(user_id:).delete_all
      Profile.where(user_id:).delete_all
    end
  end
end

module UserProfile
  # Consumer of consent.revoked: when the purpose is health_data, erases the
  # health information of that person only: sports (history included),
  # motivations and display name. The row stays with time zone and units, which
  # are technical settings, so granting the consent again works. Safe to deliver
  # again. The profile row is locked, like in the other changes of one person.
  module EraseHealthData
    PURPOSE = "health_data".freeze

    def self.call(event)
      return unless event.payload["purpose"] == PURPOSE

      Profile.transaction do
        profile = Profile.lock.find_by(user_id: event.user_id)
        SportProfile.where(user_id: event.user_id).delete_all
        profile&.update!(motivations: [], display_name: nil)
      end
    end
  end
end

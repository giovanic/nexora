module UserProfile
  # Consumer of consent.revoked: when the purpose is health_data, erases the
  # health information of that person only: sports (history included),
  # motivations and display name. The row stays with time zone and units, which
  # are technical settings, so granting the consent again works. Safe to deliver
  # again. The profile row is locked, like in the other changes of one person.
  # A consumer that runs late skips the erasure when the person granted the
  # consent again after the revoke: what exists then was written under the new
  # grant.
  module EraseHealthData
    PURPOSE = "health_data".freeze

    def self.call(event)
      return unless event.payload["purpose"] == PURPOSE

      Profile.transaction do
        profile = Profile.lock.find_by(user_id: event.user_id)
        next if Identity::Api.consent_granted_after?(user_id: event.user_id, purpose: PURPOSE, instant: event.occurred_at)

        SportProfile.where(user_id: event.user_id).delete_all
        profile&.update!(motivations: [], display_name: nil)
      end
    end
  end
end

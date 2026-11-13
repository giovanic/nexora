module UserProfile
  # Runs a write of health data with the profile row locked, and refuses it if
  # health_data is no longer granted. The check comes after the lock, so a
  # write that passed the controller's gate just before a revoke is refused
  # (the revoke is committed) or commits before EraseHealthData, which takes
  # the same lock and erases it. Answers :pending without a profile and
  # :consent_required without the consent; otherwise the value of the block.
  module LockedProfile
    def self.call(user_id:)
      Profile.transaction do
        profile = Profile.lock.find_by(user_id:)
        next :pending unless profile
        next :consent_required unless Identity::Api.consent_granted?(user_id:, purpose: EraseHealthData::PURPOSE)

        yield profile
      end
    end
  end
end

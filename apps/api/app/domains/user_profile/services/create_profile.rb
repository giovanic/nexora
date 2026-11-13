module UserProfile
  # Consumer of user.registered: the empty profile, with the time zone sent at
  # sign up. Safe to deliver again, since the user_id is the key.
  module CreateProfile
    def self.call(event)
      Profile.insert({ user_id: event.user_id, time_zone: event.payload.fetch("time_zone") }, unique_by: :user_id)
    end
  end
end

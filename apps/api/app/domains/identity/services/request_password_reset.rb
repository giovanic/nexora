module Identity
  # Starts a password reset. Known and unknown e-mails do the same work, one
  # lookup and one enqueue, so neither the answer nor its timing tells whether
  # an account exists (design 4.1). The job gets only the user id, or nil.
  module RequestPasswordReset
    def self.call(email:)
      user_id = User.active.where(email:).pick(:id) if email.is_a?(String)
      PasswordResetJob.perform_async(user_id)
      nil
    end
  end
end

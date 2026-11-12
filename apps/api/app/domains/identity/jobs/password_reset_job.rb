module Identity
  # Sends the reset link. It receives only the user id, or nil for an e-mail
  # without an account, never the e-mail or the token: Sidekiq keeps job
  # arguments in the queue and shows them in its tools. The token is made here,
  # so it only exists inside the message.
  class PasswordResetJob
    include Sidekiq::Job

    # A link that arrives much later only confuses, so few retries.
    sidekiq_options retry: 3

    def perform(user_id)
      user = User.active.find_by(id: user_id) if user_id
      return unless user

      Mailers::PasswordResetMailer.with(user:).reset_link.deliver_now
    end
  end
end

module Identity
  module Mailers
    # The link goes to the web page at APP_WEB_URL, with the token in the
    # fragment, which browsers never send to a server (design 4.9).
    class PasswordResetMailer < ActionMailer::Base
      def reset_link
        user = params.fetch(:user)
        @expires_in_minutes = User::PASSWORD_RESET_EXPIRES_IN.in_minutes.to_i
        @link = "#{Rails.configuration.x.app_web_url.to_s.chomp('/')}/reset-password#token=#{user.password_reset_token}"

        mail(to: user.email, subject: "Redefinir sua senha")
      end
    end
  end
end

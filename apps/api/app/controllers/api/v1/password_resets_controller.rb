module Api
  module V1
    class PasswordResetsController < ApplicationController
      include AuthenticationRateLimits

      allow_unauthenticated_access only: %i[create update]
      limit_attempts_by_ip :create
      limit_resets_by_email :create
      limit_attempts_by_ip :update

      # The same answer whether the e-mail has an account or not.
      def create
        Identity::Api.request_password_reset(email: params[:email])
        head :accepted
      end

      # Does not sign in: the person signs in again with the new password.
      def update
        result = Identity::Api.reset_password(token: params[:token], password: params[:password], ip: request.remote_ip)
        return head :no_content if result == true
        return render_error(:unprocessable_content, "invalid_token") if result == :invalid

        render_error(:unprocessable_content, result.code, details: result.details)
      end
    end
  end
end

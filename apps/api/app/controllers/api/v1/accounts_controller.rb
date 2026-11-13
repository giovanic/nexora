module Api
  module V1
    # The signed-in person's own account. Works without health_data, since
    # export and deletion are rights the person has either way (design 4.5).
    class AccountsController < ApplicationController
      include AuthenticationRateLimits

      limit_attempts_by_ip :export
      limit_attempts_by_ip :destroy
      limit_attempts_by_account :export
      limit_attempts_by_account :destroy

      # The password is asked again. The body holds personal data, so it is
      # built on the fly (every response is no-store, see Authentication).
      def export
        data = Identity::Api.export(user_id: current_user_id, password: params[:password], ip: request.remote_ip)
        return render_error(:unauthorized, "invalid_credentials") if data == :invalid_password

        render json: data
      end

      # The password is asked again. Every session ends now, and the erasure
      # runs in the background (design 4.4).
      def destroy
        result = Identity::Api.request_deletion(user_id: current_user_id, password: params[:password], ip: request.remote_ip)
        return render_error(:unauthorized, "invalid_credentials") if result == :invalid_password

        forget_session_cookie
        head :accepted
      end
    end
  end
end

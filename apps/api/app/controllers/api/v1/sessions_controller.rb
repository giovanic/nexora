module Api
  module V1
    class SessionsController < ApplicationController
      include AuthenticationRateLimits

      allow_unauthenticated_access only: %i[create refresh]
      limit_attempts_by_ip :create
      limit_attempts_by_email :create
      limit_attempts_by_ip :refresh

      def index
        sessions = Identity::Api.sessions(user_id: current_user_id).map do |session|
          { id: session.id, client: session.client, device_label: session.device_label, created_at: session.created_at.iso8601,
            last_used_at: session.last_used_at.iso8601, current: session.id == current_session.id }
        end

        render json: { sessions: }
      end

      def create
        fields = params.permit(:email, :password, :client, :device_label)
        unless Identity::Api.client?(fields[:client])
          return render_error(:unprocessable_content, details: [ { field: "client", code: "inclusion" } ])
        end

        result = Identity::Api.authenticate(email: fields[:email], password: fields[:password], client: fields[:client],
                                            device_label: fields[:device_label], ip: request.remote_ip)
        return render_error(:unauthorized, "invalid_credentials") if result == :invalid

        render_session(result, client: fields[:client], status: :created)
      end

      def refresh
        result = Identity::Api.refresh(token: session_token)
        return render_error(:unauthorized) unless result

        render_session(result, client: bearer_token ? "mobile" : "web", status: :ok)
      end

      def destroy_current
        Identity::Api.revoke_session(user_id: current_user_id, session_id: current_session.id)
        forget_session_cookie
        head :no_content
      end

      def destroy
        return render_error(:not_found) if Identity::Api.revoke_session(user_id: current_user_id, session_id: params[:id]) == :not_found

        forget_session_cookie if params[:id] == current_session.id
        head :no_content
      end
    end
  end
end

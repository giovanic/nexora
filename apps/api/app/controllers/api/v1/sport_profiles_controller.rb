module Api
  module V1
    # Sports of the signed-in person, with the level of each. Needs health_data.
    class SportProfilesController < ApplicationController
      require_consent :health_data

      def index
        return render_error(:conflict, "profile_pending") unless UserProfile::Api.profile(user_id: current_user_id)

        render json: { sport_profiles: UserProfile::Api.sports(user_id: current_user_id).map { |sport| serialize(sport) } }
      end

      def create
        fields = params.permit(:sport, :level)
        result = UserProfile::Api.set_sport(user_id: current_user_id, sport: fields[:sport], level: fields[:level])
        return render_error(:conflict, "profile_pending") if result == :pending
        return render_error(:forbidden, "consent_required") if result == :consent_required
        return render_error(:unprocessable_content, result.code, details: result.details) unless result.ok?

        render json: serialize(result), status: :created
      end

      def destroy
        result = UserProfile::Api.remove_sport(user_id: current_user_id, sport_id: params[:id])
        return render_error(:conflict, "profile_pending") if result == :pending
        return render_error(:forbidden, "consent_required") if result == :consent_required
        return render_error(:not_found) if result == :not_found

        head :no_content
      end

      private

      def serialize(sport)
        { id: sport.id, sport: sport.sport, level: sport.level, started_at: sport.started_at.iso8601 }
      end
    end
  end
end

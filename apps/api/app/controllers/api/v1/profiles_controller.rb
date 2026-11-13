module Api
  module V1
    # Profile of the signed-in person. Needs health_data (design 4.5). Until the
    # user.registered consumer has created it, every route answers 409 profile_pending.
    class ProfilesController < ApplicationController
      require_consent :health_data

      def show
        profile = UserProfile::Api.profile(user_id: current_user_id)
        return render_error(:conflict, "profile_pending") unless profile

        render json: serialize(profile)
      end

      def update
        # Raw values: the service refuses any type or value outside the contract, and keeps only these keys.
        fields = params.to_unsafe_h.slice("display_name", "time_zone", "motivations")
        result = UserProfile::Api.update_profile(user_id: current_user_id, attrs: fields)
        return render_error(:conflict, "profile_pending") if result == :pending
        return render_error(:unprocessable_content, result.code, details: result.details) unless result.ok?

        render json: serialize(result)
      end

      private

      def serialize(profile)
        { display_name: profile.display_name, time_zone: profile.time_zone, units: profile.units, motivations: profile.motivations }
      end
    end
  end
end

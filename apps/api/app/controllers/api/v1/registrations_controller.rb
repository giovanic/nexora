module Api
  module V1
    class RegistrationsController < ApplicationController
      include AuthenticationRateLimits

      FIELDS = %i[email password adult_confirmed time_zone client device_label].freeze

      allow_unauthenticated_access only: :create
      limit_attempts_by_ip :create
      limit_attempts_by_email :create

      def create
        fields = params.permit(*FIELDS)
        result = Identity::Api.register(**FIELDS.index_with { |field| fields[field] }, ip: request.remote_ip)
        return render_error(:unprocessable_content, result.code, details: result.details) unless result.ok?

        render_session(result, client: fields[:client], status: :created)
      end
    end
  end
end

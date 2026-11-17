module Api
  module V1
    # Authorizes the upload of a meal photo and starts the pending meal. The consent to
    # food_photo_ai and the daily quota are checked by Food AI (design 4.1). The signed URL is in the
    # body only: it is never logged, and the response is not cached (no-store).
    class FoodEntryUploadsController < ApplicationController
      # A meal and its photo are health data, as for the food catalog search.
      require_consent :health_data

      STATUS = {
        "consent_required" => :forbidden,
        "consent_operator_mismatch" => :forbidden,
        "unsupported_media_type" => :unprocessable_content,
        "validation_failed" => :unprocessable_content,
        "upload_expired" => :conflict,
        "analysis_quota_exceeded" => :too_many_requests
      }.freeze

      def create
        result = Nutrition::Api.start_photo_entry(user_id: current_user_id, client_request_id: params[:client_request_id],
                                                  content_type: params[:content_type], byte_size: params[:byte_size], meal_at: params[:meal_at])
        return render_refusal(result) unless result.ok?

        # With no URL the photo is past the upload: the same meal again, 200 instead of 201.
        render json: { food_entry_id: result.food_entry_id, status: result.status, upload_url: result.upload_url,
                       upload_headers: result.upload_headers, expires_at: result.expires_at&.iso8601 },
               status: result.upload_url ? :created : :ok
      end

      private

      def render_refusal(errors)
        response.headers["Retry-After"] = [ (errors.retry_at - Time.current).ceil, 1 ].max.to_s if errors.retry_at
        render_error(STATUS.fetch(errors.code), errors.code, details: errors.details)
      end
    end
  end
end

module FoodAi
  # The only entry point to FoodAi for other contexts and controllers. It returns Data
  # objects, never models. Photo upload and analysis operations are added by later tasks.
  module Api
    USER_DATA_TABLES = %w[food_photos food_analysis_results ai_usage_records].freeze

    UploadAuthorization = Data.define(:photo_id, :upload_url, :upload_headers, :expires_at) do
      def ok? = true
    end
    # code: consent_required, consent_operator_mismatch, unsupported_media_type, validation_failed
    # or analysis_quota_exceeded (with retry_at, the end of the local day). details: [{ field:, code: }].
    Errors = Data.define(:code, :details, :retry_at) do
      def initialize(code:, details: [], retry_at: nil) = super
      def ok? = false
    end

    class << self
      # UploadAuthorization or Errors. day_start and day_end bound the person's local day, which
      # the caller computes (FoodAi does not know time zones). The consent is checked here.
      def authorize_photo_upload(user_id:, client_request_id:, content_type:, byte_size:, day_start:, day_end:)
        AuthorizePhotoUpload.call(user_id:, client_request_id:, content_type:, byte_size:, day_start:, day_end:)
      end

      # For the boot check: raises, naming the settings and no values, when a provider is configured
      # and FOOD_AI_OPERATOR or FOOD_AI_REGION do not match the food_photo_ai text in force.
      def verify_operator!
        Config.verify_operator!
      end

      # Ties the photo to its meal. Safe to repeat. Another person's photo is left alone.
      def link_photo(user_id:, photo_id:, food_entry_id:)
        FoodPhoto.where(user_id:, id: photo_id, food_entry_id: [ nil, food_entry_id ]).update_all(food_entry_id:, updated_at: Time.current)
        nil
      end

      def export_user_data(user_id)
        UserData.export(user_id)
      end

      def erase_user_data(user_id)
        UserData.erase(user_id)
      end
    end
  end
end

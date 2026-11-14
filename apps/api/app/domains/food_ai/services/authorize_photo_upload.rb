module FoodAi
  # Authorizes one photo upload: consent, input, quota, then a row and a signed PUT URL.
  # The same client_request_id gives back the same photo with a new URL, uncounted again, or with no URL
  # once the photo is past the upload.
  # The person's advisory lock serializes the quota check and the insert; the unique index
  # on (user_id, client_request_id) stays the last defence. Signing is local, and it runs
  # outside the transaction.
  module AuthorizePhotoUpload
    CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze
    MAX_BYTES = 10 * 1024 * 1024
    MAX_REQUEST_ID = 100

    def self.call(user_id:, client_request_id:, content_type:, byte_size:, day_start:, day_end:)
      code = ConsentGate.check(user_id:)
      return failure(code) if code
      return failure("unsupported_media_type", field: "content_type", code: "unsupported") unless CONTENT_TYPES.include?(content_type)

      invalid = invalid_fields(client_request_id, byte_size)
      return Api::Errors.new(code: "validation_failed", details: invalid) if invalid.any?

      photo = reserve(user_id:, client_request_id:, content_type:, byte_size:, day_start:, day_end:)
      return photo if photo.is_a?(Api::Errors) || photo.is_a?(Api::UploadAuthorization)

      upload = FoodAi.storage.presigned_put(key: photo.object_key, content_type:, byte_size:)
      Api::UploadAuthorization.new(photo_id: photo.id, upload_url: upload.url, upload_headers: upload.headers, expires_at: upload.expires_at)
    end

    def self.invalid_fields(client_request_id, byte_size)
      details = []
      details << { field: "client_request_id", code: "invalid" } unless client_request_id.is_a?(String) && client_request_id.strip.present? && client_request_id.length <= MAX_REQUEST_ID
      if !byte_size.is_a?(Integer) then details << { field: "byte_size", code: "not_an_integer" }
      elsif byte_size < 1 then details << { field: "byte_size", code: "too_small" }
      elsif byte_size > MAX_BYTES then details << { field: "byte_size", code: "too_large" }
      end
      details
    end

    def self.reserve(user_id:, client_request_id:, content_type:, byte_size:, day_start:, day_end:)
      attempts = 0
      begin
        FoodPhoto.transaction do
          lock(user_id)
          existing = FoodPhoto.find_by(user_id:, client_request_id:)
          next reuse(existing, content_type:, byte_size:) if existing

          retry_at = CheckAnalysisQuota.exceeded_until(user_id:, day_start:, day_end:)
          next Api::Errors.new(code: "analysis_quota_exceeded", retry_at:) if retry_at

          FoodPhoto.create!(user_id:, client_request_id:, object_key: "food-photos/#{SecureRandom.uuid}", content_type:, byte_size:, authorized_at: Time.current)
        end
      rescue ActiveRecord::RecordNotUnique
        attempts += 1
        retry if attempts < 3
        raise
      end
    end

    def self.reuse(photo, content_type:, byte_size:)
      # Past the upload: the same meal, and no URL to upload to again.
      return Api::UploadAuthorization.new(photo_id: photo.id, upload_url: nil, upload_headers: nil, expires_at: nil) unless photo.status == "awaiting_upload"

      photo.update!(content_type:, byte_size:) unless photo.content_type == content_type && photo.byte_size == byte_size
      photo
    end

    def self.lock(user_id)
      FoodPhoto.connection.execute(FoodPhoto.sanitize_sql([ "SELECT pg_advisory_xact_lock(hashtextextended(?, 0))::text", "food_photo:#{user_id}" ]))
    end

    def self.failure(code, field: nil, **detail)
      Api::Errors.new(code:, details: field ? [ { field:, **detail } ] : [])
    end
    private_class_method :invalid_fields, :reserve, :reuse, :lock, :failure
  end
end

module FoodAi
  # The only entry point to FoodAi for other contexts and controllers. It returns Data
  # objects, never models. Photo upload and analysis operations are added by later tasks.
  module Api
    USER_DATA_TABLES = %w[food_photos food_analysis_results ai_usage_records].freeze

    UploadAuthorization = Data.define(:photo_id, :upload_url, :upload_headers, :expires_at) do
      def ok? = true
    end
    # code: consent_required, consent_operator_mismatch, unsupported_media_type, validation_failed, upload_expired
    # or analysis_quota_exceeded (with retry_at, the end of the local day). details: [{ field:, code: }].
    Errors = Data.define(:code, :details, :retry_at) do
      def initialize(code:, details: [], retry_at: nil) = super
      def ok? = false
    end

    # status: succeeded, no_food, unreadable, failed, cancelled or running. items: [FoodAi::ItemInfo],
    # empty unless succeeded. note_codes: closed list of the prompt schema.
    AnalysisInfo = Data.define(:id, :status, :items, :note_codes)

    # analyses: provider calls (usage records) in the period. cost_usd: BigDecimal.
    UsageSummary = Data.define(:analyses, :cost_usd)

    class << self
      # The provider calls and their cost in [from, to), for one person or, with user_id nil, for everyone
      # (records unlinked by the retention included). NFR-COST-001.
      def usage(user_id:, from:, to:)
        scope = UsageRecord.where(occurred_at: from...to)
        scope = scope.where(user_id:) if user_id
        UsageSummary.new(analyses: scope.count, cost_usd: scope.sum(:cost_usd))
      end

      # :enqueued or Errors (not_uploaded, invalid_photo with details, consent_required,
      # consent_operator_mismatch, analysis_retry_limit, analysis_quota_exceeded with retry_at). The caller owns the
      # meal; FoodAi checks the photo is the person's. day_start and day_end bound the person's local day.
      def request_analysis(user_id:, photo_id:, food_entry_id:, day_start:, day_end:)
        RequestAnalysis.call(user_id:, photo_id:, food_entry_id:, day_start:, day_end:)
      end

      # AnalysisInfo, or :not_found. By identifier only: it comes from an event, never from a client.
      def analysis(analysis_id:)
        PhotoCleanup.analysis_info(analysis_id)
      end

      # The meal was deleted: the object, the photo and the analyses go; cost records stay unlinked.
      # photo_id: the meal's photo_id, for a photo not yet linked back to the meal. A storage failure does not
      # fail the erasure: the photo is marked deleted and PurgeObjectJob retries the object.
      def erase_for_entry(user_id:, food_entry_id:, photo_id: nil)
        PhotoCleanup.erase_for_entry(user_id:, food_entry_id:, photo_id:)
      end

      # Recovery of a meal stuck in processing: :republished, :enqueued, :running, or Errors photo_missing /
      # analysis_failed (the caller fails the meal). One provider call at most, whatever the repeats.
      def resume_analysis(user_id:, photo_id:, food_entry_id:)
        ResumeAnalysis.call(user_id:, photo_id:, food_entry_id:)
      end

      # A failure that is ours returns the quota unit of the photo (design 4.12). Safe to repeat: the first
      # refund keeps its date. Another person's or an unknown photo is left alone.
      def refund_quota(user_id:, photo_id:)
        FoodPhoto.where(user_id:, id: photo_id, quota_refunded_at: nil).update_all(quota_refunded_at: Time.current, updated_at: Time.current)
        nil
      end

      # Deletes the object and the photo that has no analysis: :discarded, :in_use or :not_found.
      def discard_photo(user_id:, photo_id:)
        PhotoCleanup.discard_photo(user_id:, photo_id:)
      end

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

      # A signed GET URL (15 minutes at most) for the person's stored photo, or nil when the photo is
      # absent, deleted, not uploaded yet or another person's. The URL is a secret: never log it.
      def photo_url(user_id:, photo_id:)
        return unless photo_id

        photo = FoodPhoto.find_by(user_id:, id: photo_id, status: "stored")
        photo && FoodAi.storage.presigned_get(key: photo.object_key, expires_in: Adapters::ObjectStorage::MAX_EXPIRES_IN)
      end

      # { photo_id => signed GET URL } for the person's stored photos among photo_ids, in one query. The
      # same rules as photo_url; a photo that is absent, deleted or not the person's has no key.
      def photo_urls(user_id:, photo_ids:)
        ids = Array(photo_ids).compact
        return {} if ids.empty?

        FoodPhoto.where(user_id:, id: ids, status: "stored").to_h do |photo|
          [ photo.id, FoodAi.storage.presigned_get(key: photo.object_key, expires_in: Adapters::ObjectStorage::MAX_EXPIRES_IN) ]
        end
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

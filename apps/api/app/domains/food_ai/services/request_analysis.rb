module FoodAi
  # Starts the analysis of an uploaded photo: consent, then the object in storage against what was
  # authorized (size and type), then the photo is marked stored and the job is enqueued. A failed
  # meal asks again for the same photo, which clears its quota refund (the unit counts again, today, and is
  # checked against the quota under the person's lock). The photo takes at most MAX_REQUESTS requests
  # (analysis_retry_limit after that).
  # The storage is asked outside any transaction.
  module RequestAnalysis
    # The first request and two new ones after a failure.
    MAX_REQUESTS = 3

    def self.call(user_id:, photo_id:, food_entry_id:, day_start:, day_end:)
      photo = FoodPhoto.find_by(user_id:, id: photo_id)
      return error("not_uploaded") if photo.nil? || photo.status == "deleted" || (photo.food_entry_id && photo.food_entry_id != food_entry_id)

      code = ConsentGate.check(user_id:)
      return error(code) if code

      info = FoodAi.storage.head(key: photo.object_key)
      return error("not_uploaded") if info.nil?

      mismatch = mismatch_code(photo, info)
      return error("invalid_photo", details: [ { field: "photo", code: mismatch } ]) if mismatch

      outcome = mark_stored(photo, food_entry_id, day_start:, day_end:)
      return outcome if outcome.is_a?(Api::Errors)
      return error("not_uploaded") unless outcome

      AnalyzeJob.perform_async(photo.id)
      :enqueued
    end

    def self.mismatch_code(photo, info)
      return "size_mismatch" unless info.byte_size == photo.byte_size
      return "type_mismatch" unless info.content_type.to_s.split(";").first == photo.content_type

      nil
    end

    # True when stored; false when the photo was deleted meanwhile; Errors when this would be a new request
    # beyond the limit, or beyond the day's quota. The person's lock serializes the quota check with new uploads.
    def self.mark_stored(photo, food_entry_id, day_start:, day_end:)
      FoodPhoto.transaction do
        PersonLock.call(photo.user_id)
        locked = FoodPhoto.lock.find(photo.id)
        next false if locked.status == "deleted"
        next error("analysis_retry_limit") if locked.analysis_requests >= MAX_REQUESTS

        attributes = { status: "stored", food_entry_id:, quota_refunded_at: nil, analysis_requests: locked.analysis_requests + 1 }
        if locked.quota_refunded_at
          # Asking again after a failure takes the unit back, counted in the person's day of today.
          retry_at = CheckAnalysisQuota.exceeded_until(user_id: locked.user_id, day_start:, day_end:)
          next error("analysis_quota_exceeded", retry_at:) if retry_at

          attributes[:authorized_at] = Time.current
        end
        locked.update!(**attributes)
        true
      end
    end

    def self.error(code, details: [], retry_at: nil)
      Api::Errors.new(code:, details:, retry_at:)
    end
    private_class_method :mismatch_code, :mark_stored, :error
  end
end

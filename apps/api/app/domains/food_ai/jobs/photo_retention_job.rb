module FoodAi
  # Daily (config/schedule.yml). Two steps, both safe to repeat:
  #
  # 1. A stored photo whose analysis is older than 30 days loses its object and is marked deleted. The
  #    object goes first (outside any transaction); if storage fails the photo stays stored and the
  #    next run tries again. The meal stays.
  # 1b. Photos that were never analyzed are bounded too (health data must not wait for a meal that never
  #    came): an upload not finished one hour after authorization, and a stored photo untouched for 24 hours
  #    that has no running analysis updated in the last 24 hours (a meal that failed and was not retried).
  #    Same sequence: the object first, then the mark. The meal of such a photo is pending (the abandoned
  #    routine deletes it) or failed (the person retries with a new photo, or deletes it).
  # 2. Sweeper: every photo marked deleted gets its object deleted again (a purge that failed or was
  #    lost with Redis). The row is the only record of the object key, so it is removed only when the
  #    object deletion succeeded in this run AND the photo has been deleted for 7 days (so a job still
  #    running finds the row and drops its result). A row whose object cannot be deleted stays, however
  #    old, and is tried again every day.
  #
  # The log line carries counts only.
  class PhotoRetentionJob
    include Sidekiq::Job

    sidekiq_options retry: false

    AFTER_ANALYSIS = 30.days
    ROW_GRACE = 7.days
    UNFINISHED_UPLOAD = 1.hour
    UNANALYZED = 24.hours

    def perform
      result = { expired: expire_analyzed + expire_unfinished, swept: sweep_deleted }
      Sidekiq.logger.info("food photo retention #{result.map { |name, count| "#{name}=#{count}" }.join(' ')}")
      result
    end

    private

    def expire_analyzed
      expire(FoodPhoto.where(status: "stored", analyzed_at: ...AFTER_ANALYSIS.ago))
    end

    def expire_unfinished
      running = AnalysisResult.where(status: "running", updated_at: UNANALYZED.ago..).select(:photo_id)
      expire(FoodPhoto.where(status: "awaiting_upload", authorized_at: ...UNFINISHED_UPLOAD.ago)) +
        expire(FoodPhoto.where(status: "stored", analyzed_at: nil, updated_at: ...UNANALYZED.ago).where.not(id: running))
    end

    def expire(scope)
      count = 0
      scope.find_each do |photo|
        next unless delete_object(photo)

        FoodPhoto.transaction do
          locked = FoodPhoto.lock.find(photo.id)
          if locked.status == photo.status && (locked.analyzed_at.nil? == photo.analyzed_at.nil?)
            locked.update!(status: "deleted", deleted_at: Time.current)
            count += 1
          end
        end
      end
      count
    end

    def sweep_deleted
      removed = 0
      FoodPhoto.where(status: "deleted").find_each do |photo|
        next unless delete_object(photo)

        deleted_at = photo.deleted_at || photo.updated_at
        next unless deleted_at <= ROW_GRACE.ago

        removed += FoodPhoto.where(id: photo.id, status: "deleted").delete_all
      end
      removed
    end

    # The error is not kept: it may name the key.
    def delete_object(photo)
      FoodAi.storage.delete(key: photo.object_key)
      true
    rescue StandardError
      false
    end
  end
end

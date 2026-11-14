module FoodAi
  # Daily (config/schedule.yml). Two steps, both safe to repeat:
  #
  # 1. A stored photo whose analysis is older than 30 days loses its object and is marked deleted. The
  #    object goes first (outside any transaction); if storage fails the photo stays stored and the
  #    next run tries again. The meal stays.
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

    def perform
      result = { expired: expire_analyzed, swept: sweep_deleted }
      Sidekiq.logger.info("food photo retention #{result.map { |name, count| "#{name}=#{count}" }.join(' ')}")
      result
    end

    private

    def expire_analyzed
      count = 0
      FoodPhoto.where(status: "stored", analyzed_at: ...AFTER_ANALYSIS.ago).find_each do |photo|
        next unless delete_object(photo)

        FoodPhoto.transaction do
          locked = FoodPhoto.lock.find(photo.id)
          locked.update!(status: "deleted", deleted_at: Time.current) if locked.status == "stored"
        end
        count += 1
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

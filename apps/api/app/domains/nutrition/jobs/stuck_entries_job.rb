module Nutrition
  # Every 10 minutes (config/schedule.yml). A meal in processing for more than 15 minutes lost its job
  # (process killed, Redis lost) or its event. FoodAi resumes it (FoodAi::Api.resume_analysis, one provider
  # call at most) and the meal's resume_attempts goes up by one. The meal becomes failed, so the person can
  # try again, and the quota unit of its photo is refunded (a failure that is ours), when:
  #  - FoodAi cannot resume it (photo gone, or the last run failed), or it has no photo;
  #  - it was already resumed MAX_RESUMES times and is still processing (an event nobody applies must not
  #    be republished forever). A new analysis request resets the counter.
  # One meal that raises does not stop the others; only its id is logged.
  class StuckEntriesJob
    include Sidekiq::Job

    sidekiq_options retry: false

    AFTER = 15.minutes
    MAX_RESUMES = 3

    def perform
      failed = 0
      FoodEntry.where(status: "processing", updated_at: ...AFTER.ago).find_each do |entry|
        failed += resume(entry)
      rescue StandardError => error
        Rails.logger.warn("nutrition stuck entry not resumed entry_id=#{entry.id} error=#{error.class}")
      end
      Sidekiq.logger.info("nutrition stuck entries failed=#{failed}")
      failed
    end

    private

    # 1 when the meal was marked failed, 0 otherwise.
    def resume(entry)
      return fail_entry(entry) if entry.photo_id.nil? || entry.resume_attempts >= MAX_RESUMES

      result = FoodAi::Api.resume_analysis(user_id: entry.user_id, photo_id: entry.photo_id, food_entry_id: entry.id)
      return fail_entry(entry) unless result.is_a?(Symbol)

      FoodEntry.where(id: entry.id, status: "processing").update_all("resume_attempts = resume_attempts + 1")
      0
    end

    def fail_entry(entry)
      changed = FoodEntry.where(id: entry.id, status: "processing").update_all(status: "failed", updated_at: Time.current)
      FoodAi::Api.refund_quota(user_id: entry.user_id, photo_id: entry.photo_id) if entry.photo_id
      changed
    end
  end
end

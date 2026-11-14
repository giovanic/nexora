module Nutrition
  # Every 10 minutes (config/schedule.yml). A meal in processing for more than 15 minutes lost its job
  # (process killed, Redis lost) or its event. FoodAi resumes it (FoodAi::Api.resume_analysis, one provider
  # call at most); when the photo is gone, or the last run failed, the meal becomes failed so the person can
  # try again. A meal without a photo cannot be analyzed, so it fails too. One meal that raises does not stop
  # the others; only its id is logged.
  class StuckEntriesJob
    include Sidekiq::Job

    sidekiq_options retry: false

    AFTER = 15.minutes

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
      result = entry.photo_id && FoodAi::Api.resume_analysis(user_id: entry.user_id, photo_id: entry.photo_id, food_entry_id: entry.id)
      return 0 if result.is_a?(Symbol)

      FoodEntry.where(id: entry.id, status: "processing").update_all(status: "failed", updated_at: Time.current)
    end
  end
end

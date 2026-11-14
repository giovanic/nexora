module Nutrition
  # Hourly (config/schedule.yml). A meal still pending an hour after it was created never got its photo
  # analyzed: the upload was abandoned. FoodAi deletes the photo and its object first (an external call,
  # outside any transaction); if the photo is in use by an analysis the meal stays. Then the meal goes, but
  # only if it is still pending (a request that started the analysis meanwhile wins). Safe to repeat.
  # The log line carries a count only.
  class AbandonedEntriesJob
    include Sidekiq::Job

    sidekiq_options retry: false

    AFTER = 1.hour

    def perform
      deleted = 0
      FoodEntry.where(status: "pending", created_at: ...AFTER.ago).find_each do |entry|
        next if entry.photo_id && FoodAi::Api.discard_photo(user_id: entry.user_id, photo_id: entry.photo_id) == :in_use

        deleted += FoodEntry.where(id: entry.id, status: "pending").delete_all
      end
      Sidekiq.logger.info("nutrition abandoned entries deleted=#{deleted}")
      deleted
    end
  end
end

module Goals
  # Daily (config/schedule.yml). Deletes the deleted-meal markers 30 days after they were created, the same period as
  # the published outbox events (Shared::Outbox::CleanupJob::PERIOD): after that a late food_entry.confirmed is no
  # longer expected. In batches, safe to repeat. Counts only in the log.
  class RemovedFoodEntriesRetentionJob
    include Sidekiq::Job

    sidekiq_options retry: false

    BATCH = 1_000
    PERIOD = Shared::Outbox::CleanupJob::PERIOD

    def perform
      deleted = 0
      RemovedFoodEntry.where(created_at: ...(Time.current - PERIOD)).in_batches(of: BATCH) { |batch| deleted += batch.delete_all }
      Sidekiq.logger.info("goals retention removed_food_entries=#{deleted}")
      { removed_food_entries: deleted }
    end
  end
end

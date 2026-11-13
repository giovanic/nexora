module Shared
  module Outbox
    # Daily (config/schedule.yml). Removes events 30 days after they were
    # processed, published or dead (DATABASE_DESIGN.md, "Retenção"). Their
    # consumed_events rows go with them (foreign key ON DELETE CASCADE).
    # Pending events stay, however old: someone still has to apply them.
    # Deletes in batches and finds nothing on a second run.
    class CleanupJob
      include Sidekiq::Job

      sidekiq_options retry: false

      BATCH = 1_000
      PERIOD = 30.days

      def perform
        cutoff = Time.current - PERIOD
        scope = Event.where(published_at: ..cutoff).or(Event.where(dead_at: ..cutoff))
        total = 0
        scope.in_batches(of: BATCH) { |batch| total += batch.delete_all }
        Sidekiq.logger.info("outbox cleanup events=#{total}")
        { events: total }
      end
    end
  end
end

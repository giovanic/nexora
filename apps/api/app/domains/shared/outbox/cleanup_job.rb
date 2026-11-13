module Shared
  module Outbox
    # Daily (config/schedule.yml). Removes events 30 days after they were
    # published (DATABASE_DESIGN.md, "Retenção"). Their consumed_events rows go
    # with them (foreign key ON DELETE CASCADE). Pending and dead events stay,
    # however old: they were never processed, someone still has to apply or
    # resolve them (docs/operations/RUNBOOK_OUTBOX.md), and a dead
    # consent.revoked keeps blocking a new health_data grant until then.
    # Deletes in batches and finds nothing on a second run.
    class CleanupJob
      include Sidekiq::Job

      sidekiq_options retry: false

      BATCH = 1_000
      PERIOD = 30.days

      def perform
        cutoff = Time.current - PERIOD
        scope = Event.where(published_at: ..cutoff)
        total = 0
        scope.in_batches(of: BATCH) { |batch| total += batch.delete_all }
        Sidekiq.logger.info("outbox cleanup events=#{total}")
        { events: total }
      end
    end
  end
end

module Shared
  module Outbox
    # Delivers pending events to their consumers. Runs after each commit that
    # published an event, and every minute from config/schedule.yml.
    #
    # Each event is locked with SKIP LOCKED for the whole delivery, so two runs
    # at once never handle the same event. Each consumer runs in a savepoint
    # with its consumed_events row: a failure undoes only that consumer, and a
    # consumer that already succeeded is skipped on the next attempt.
    class PublishJob
      include Sidekiq::Job

      # The cron run is the retry; a failed run must not pile up copies.
      sidekiq_options retry: false

      BATCH_SIZE = 200

      def perform
        BATCH_SIZE.times do
          delivered, alerts = deliver_next
          alerts.each { |consumer| alert_dead(consumer) }
          break unless delivered
        end
      end

      private

      # Returns whether an event was handled, and the consumers to alert about,
      # which the caller reports after the transaction commits.
      def deliver_next
        Event.transaction do
          event = Event.due.order(:occurred_at).lock("FOR UPDATE SKIP LOCKED").first
          next [ false, [] ] unless event

          if Outbox.discard?(event)
            event.destroy!
            next [ true, [] ]
          end

          failed = Outbox.consumers_for(event.name).reject { |consumer| consume(consumer, event) }
          [ true, record_result(event, failed) ]
        end
      end

      def consume(consumer, event)
        applied = Event.transaction(requires_new: true) do
          inserted = ConsumedEvent.insert(
            { consumer: consumer.name, event_id: event.id, consumed_at: Time.current },
            unique_by: %i[consumer event_id], returning: %i[event_id]
          )
          consumer.handler.call(event) if inserted.rows.any?
          true
        end
        # A handler that raised ActiveRecord::Rollback also undid its consumed_events
        # row, so it failed: raised here, it takes the path of any other failure.
        raise ActiveRecord::Rollback unless applied

        true
      rescue StandardError => error
        # The message can carry user data, so only identifiers and the class go to the log.
        Rails.logger.warn("outbox consumer failed event_id=#{event.id} event=#{event.name} consumer=#{consumer.name} error=#{error.class}")
        false
      end

      def record_result(event, failed)
        now = Time.current
        if failed.empty?
          event.update!(published_at: now, next_attempt_at: nil)
          return []
        end

        attempts = event.attempts + 1
        if attempts >= MAX_ATTEMPTS
          event.update!(attempts:, dead_at: now, next_attempt_at: nil)
          failed
        else
          # 1, 2, 4 ... 64 minutes: about two hours before an event dies.
          event.update!(attempts:, next_attempt_at: now + (2**(attempts - 1)).minutes)
          []
        end
      end

      def alert_dead(consumer)
        Sentry.capture_exception(DeadEvent.new, tags: { outbox_event: consumer.event_name, outbox_consumer: consumer.name })
      end
    end
  end
end

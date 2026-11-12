module Shared
  module Outbox
    # Delivers pending events to their consumers. Runs after each commit that
    # published an event, and every minute from config/schedule.yml.
    #
    # Each event is locked with SKIP LOCKED for the whole delivery, so two runs
    # at once never handle the same event. Each consumer runs in a savepoint
    # with its consumed_events row: a failure undoes only that consumer, and a
    # consumer that already succeeded is skipped on the next attempt. A failure
    # of the publisher's own steps, a discard rule or the bookkeeping, also
    # counts as an attempt of that event, so it never holds back the next ones.
    class PublishJob
      include Sidekiq::Job

      # The cron run is the retry; a failed run must not pile up copies.
      sidekiq_options retry: false

      BATCH_SIZE = 200
      # The publisher's own steps, named where a failure names a consumer.
      DISCARD_RULE = "outbox.discard_rule".freeze
      PUBLISHER = "outbox.publisher".freeze

      def perform
        BATCH_SIZE.times do
          event_name, dead_for = deliver_next
          dead_for.each { |consumer| alert_dead(event_name, consumer) }
          break unless event_name
        end
      end

      private

      # Returns the name of the event handled, nil when none is due, and the
      # consumers it died for, which the caller reports after the commit.
      def deliver_next
        event = nil
        step = DISCARD_RULE
        Event.transaction do
          event = Event.due.order(:occurred_at).lock("FOR UPDATE SKIP LOCKED").first
          next [ nil, [] ] unless event

          if Outbox.discard?(event)
            event.destroy!
            next [ event.name, [] ]
          end

          step = PUBLISHER
          failed = Outbox.consumers_for(event.name).reject { |consumer| consume(consumer, event) }
          [ event.name, record_result(event, failed.map(&:name)) ]
        end
      rescue StandardError => error
        # Without an event, the database itself failed: the next run retries.
        raise unless event

        # The event's transaction rolled back, consumers included. Counting the
        # attempt in a new one keeps it from holding back the events after it.
        log_failure(event, step, error)
        [ event.name, record_failure(event.id, step) ]
      end

      def record_failure(event_id, step)
        Event.transaction do
          # Another run may have taken the event once the rollback released it.
          event = Event.due.lock("FOR UPDATE SKIP LOCKED").find_by(id: event_id)
          event ? record_result(event, [ step ]) : []
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
        log_failure(event, consumer.name, error)
        false
      end

      # The message can carry user data, so only identifiers and the class go to the log.
      def log_failure(event, consumer_name, error)
        Rails.logger.warn("outbox delivery failed event_id=#{event.id} event=#{event.name} consumer=#{consumer_name} error=#{error.class}")
      end

      # failed holds consumer names; returns those to alert about when the event dies.
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

      def alert_dead(event_name, consumer_name)
        Sentry.capture_exception(DeadEvent.new, tags: { outbox_event: event_name, outbox_consumer: consumer_name })
      end
    end
  end
end

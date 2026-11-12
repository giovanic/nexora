module Shared
  module Outbox
    # Hourly check (config/schedule.yml): reports, per event name and consumer,
    # events written more than an hour ago that the consumer has not applied.
    # Published events had every consumer of their time, and dead events
    # already raised their own alert, so only pending ones count.
    class ReconcileJob
      include Sidekiq::Job

      sidekiq_options retry: false

      GRACE = 1.hour

      def perform
        report = Outbox.subscriptions.filter_map do |consumer|
          count = missing(consumer).count
          { event: consumer.event_name, consumer: consumer.name, count: } if count.positive?
        end
        report.each { |line| alert(line) }
        report
      end

      private

      def missing(consumer)
        Event.pending
          .where(name: consumer.event_name, occurred_at: ..GRACE.ago)
          .where.not(id: ConsumedEvent.where(consumer: consumer.name).select(:event_id))
      end

      def alert(line)
        Sentry.capture_exception(MissingConsumption.new, tags: { outbox_event: line[:event], outbox_consumer: line[:consumer] })
      end
    end
  end
end

module Shared
  # Transactional outbox (ADR 0004). A context records a fact with publish!,
  # inside the transaction of the change; PublishJob delivers it later to every
  # consumer, at least once. Each consumer runs in its own savepoint together
  # with its consumed_events row, so a repeated delivery has no effect.
  #
  # A consumer runs inside that transaction, so it only writes to the database:
  # external calls go to a job it enqueues after commit, or to another event.
  #
  # Consumers and discard rules live in memory and are rebuilt on every code
  # load, so contexts register them inside `Rails.application.config.to_prepare`.
  module Outbox
    DELETION_REQUESTED = "user.deletion_requested".freeze
    MAX_ATTEMPTS = 8
    # Also names the consumer in an alert tag, so it holds no free text.
    CONSUMER_NAME = /\A[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+\z/

    class NotInTransaction < StandardError; end
    class InvalidPayload < ArgumentError; end

    # Raised for the error tracker only, never thrown: they carry no message,
    # and the alert names the event and the consumer in tags.
    class DeadEvent < StandardError; end
    class MissingConsumption < StandardError; end

    Consumer = Data.define(:event_name, :name, :handler)

    @consumers = {}
    @discard_rules = []

    class << self
      # Must run inside the caller's transaction, so the event exists only if
      # the change does. Payload values are identifiers or closed-list values.
      def publish!(name:, user_id:, payload: {}, version: 1, correlation_id: nil)
        # Tests wrap each example in a transaction that does not accept joins,
        # so this also refuses a call that would only be inside that one.
        raise NotInTransaction, "publish! must run inside a transaction" unless Event.lease_connection.current_transaction.joinable?

        PayloadCheck.call(payload)
        event = Event.create!(name:, user_id:, payload:, version:, correlation_id:, occurred_at: Time.current)
        # The cron run every minute stays as the safety net (config/schedule.yml).
        Event.current_transaction.after_commit { enqueue_publisher } if enqueue_after_commit?
        event
      end

      # True while an event of the person with that name (and, when given, that
      # payload) was not delivered to every consumer. A dead event counts: it
      # was not applied either. Lets a context wait for its own earlier change
      # to take effect without reading the table.
      def undelivered?(name:, user_id:, payload: {})
        scope = Event.where(name:, user_id:, published_at: nil)
        scope = scope.where("payload @> ?::jsonb", payload.to_json) if payload.present?
        scope.exists?
      end

      def subscribe(event_name, consumer:, &handler)
        raise ArgumentError, "subscribe needs a block" unless handler
        raise ArgumentError, "consumer must look like context.action" unless consumer.to_s.match?(CONSUMER_NAME)

        (@consumers[event_name.to_s] ||= {})[consumer.to_s] = Consumer.new(event_name: event_name.to_s, name: consumer.to_s, handler:)
        nil
      end

      def consumers_for(event_name)
        @consumers.fetch(event_name.to_s, {}).values
      end

      def subscriptions
        @consumers.values.flat_map(&:values)
      end

      # Registers a rule for events that must not be delivered, such as those of
      # a user whose deletion was requested. user.deletion_requested is never discarded.
      def discard_if(&rule)
        raise ArgumentError, "discard_if needs a block" unless rule

        @discard_rules << rule
        nil
      end

      def discard?(event)
        return false if event.name == DELETION_REQUESTED

        @discard_rules.any? { |rule| rule.call(event) }
      end

      # Events hold only identifiers, so the export has nothing to show.
      def export_user_data(_user_id)
        {}
      end

      # Keeps user.deletion_requested, which the deletion itself still needs.
      def erase_user_data(user_id)
        Event.where(user_id:).where.not(name: DELETION_REQUESTED).delete_all
      end

      # Lets specs register handlers without leaking them into other examples.
      def preserving_registrations
        saved = [ @consumers.transform_values(&:dup), @discard_rules.dup ]
        yield
      ensure
        @consumers, @discard_rules = saved
      end

      private

      def enqueue_after_commit?
        Rails.configuration.x.outbox_enqueue_after_commit != false
      end

      # Runs after the commit, so raising would fail a change that succeeded.
      # The enqueue only speeds delivery up: the cron delivers without it.
      def enqueue_publisher
        PublishJob.perform_async
      rescue StandardError => error
        # The message can name the queue host, so only the class goes to the log.
        Rails.logger.warn("outbox publisher not enqueued, the cron delivers instead error=#{error.class}")
      end
    end
  end
end

require "observability/correlation"

module Observability
  # Last check before an event leaves the application. It removes what the SDK
  # options do not cover, so the report holds the exception class and stack,
  # never data about a person. An exception message can carry user data, so it
  # goes too.
  module ErrorScrubber
    SIDEKIQ_CONTEXT_KEEP = %w[class jid queue correlation_id].freeze

    def self.call(event, _hint)
      remove_exception_messages(event)
      remove_request_data(event)
      event.breadcrumbs = nil
      event.user = {}
      event.extra = {}

      sidekiq = scrub_sidekiq_context(event)
      correlation_id = Observability::Correlation.id || sidekiq["correlation_id"]
      event.tags = event.tags.merge(correlation_id:) if correlation_id
      event
    end

    def self.remove_exception_messages(event)
      event.message = nil if event.respond_to?(:message=)
      return unless event.respond_to?(:exception) && event.exception

      event.exception.values.each do |single|
        single.value = nil
        single.stacktrace&.frames&.each { |frame| frame.context_line = nil }
      end
    end
    private_class_method :remove_exception_messages

    def self.remove_request_data(event)
      request = event.request
      return unless request

      request.url = nil
      request.data = nil
      request.query_string = nil
      request.cookies = nil
      request.headers = nil
      request.env = nil
    end
    private_class_method :remove_request_data

    def self.scrub_sidekiq_context(event)
      context = event.contexts[:sidekiq]
      return {} unless context

      kept = context.transform_keys(&:to_s).slice(*SIDEKIQ_CONTEXT_KEEP)
      event.contexts = event.contexts.merge(sidekiq: kept)
      kept
    end
    private_class_method :scrub_sidekiq_context
  end
end

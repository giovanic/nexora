require "observability/correlation"

module Observability
  # Last check before an event leaves the application. It removes what the SDK
  # options do not cover, and allows only known fields, so the report holds the
  # exception class and stack, never data about a person. An exception message
  # can carry user data, so it goes too.
  module ErrorScrubber
    KEPT_TAGS = %w[correlation_id request_id].freeze
    KEPT_CONTEXTS = %w[runtime sidekiq].freeze
    SIDEKIQ_CONTEXT_KEEP = %w[class jid queue correlation_id].freeze
    UNROUTED = "unrouted".freeze

    def self.call(event, _hint)
      remove_exception_messages(event)
      remove_request_data(event)
      replace_url_transaction(event)
      event.breadcrumbs = nil
      event.user = {}
      event.extra = {}
      event.fingerprint = []

      sidekiq = keep_known_contexts(event)
      keep_known_tags(event, Observability::Correlation.id || sidekiq["correlation_id"])
      event
    end

    def self.remove_exception_messages(event)
      event.message = nil if event.respond_to?(:message=)
      return unless event.respond_to?(:exception) && event.exception

      event.exception.values.each do |single|
        single.value = nil
        single.stacktrace&.frames&.each do |frame|
          frame.context_line = nil
          frame.abs_path = nil
        end
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

    # A failure before routing names the transaction after the URL, which can hold data.
    def self.replace_url_transaction(event)
      event.transaction = UNROUTED if event.transaction_info&.dig(:source) == :url
    end
    private_class_method :replace_url_transaction

    def self.keep_known_contexts(event)
      contexts = event.contexts.transform_keys(&:to_s).slice(*KEPT_CONTEXTS)
      sidekiq = (contexts["sidekiq"] || {}).transform_keys(&:to_s).slice(*SIDEKIQ_CONTEXT_KEEP)
      contexts["sidekiq"] = sidekiq if contexts.key?("sidekiq")
      event.contexts = contexts.transform_keys(&:to_sym)
      sidekiq
    end
    private_class_method :keep_known_contexts

    def self.keep_known_tags(event, correlation_id)
      tags = event.tags.transform_keys(&:to_s).slice(*KEPT_TAGS).transform_keys(&:to_sym)
      tags[:correlation_id] = correlation_id if correlation_id
      event.tags = tags
    end
    private_class_method :keep_known_tags
  end
end

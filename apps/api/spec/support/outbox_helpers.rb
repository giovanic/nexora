require "sentry/test_helper"

# Registrations live in memory for the whole process, so each example that adds
# consumers, discard rules or data handlers gets them removed afterwards. The
# contexts' own consumers (registered at boot) are cleared too, so a spec of the
# publisher sees only what it subscribes; tag an example with :real_consumers to keep them.
module OutboxHelpers
  def self.included(base)
    base.include ActiveSupport::Testing::TimeHelpers
    base.around do |example|
      Shared::Outbox.preserving_registrations do
        Shared::Outbox.instance_variable_set(:@consumers, {}) unless example.metadata[:real_consumers]
        Shared::DataRegistry.preserving_registrations { example.run }
      end
    end
  end

  def publish(name: "user.registered", user_id: SecureRandom.uuid, payload: {})
    ActiveRecord::Base.transaction { Shared::Outbox.publish!(name:, user_id:, payload:) }
  end

  def run_publisher
    Shared::Outbox::PublishJob.new.perform
  end
end

# Starts the error tracker with a dummy DSN, so examples can read the events it
# would send, after the scrubber has run.
module SentryCapture
  def self.included(base)
    base.include Sentry::TestHelper
    base.before do
      Observability::ErrorTracking.start("ERROR_TRACKING_DSN" => Sentry::TestHelper::DUMMY_DSN)
      setup_sentry_test
    end
    base.after do
      teardown_sentry_test
      Sentry.close
    end
  end
end

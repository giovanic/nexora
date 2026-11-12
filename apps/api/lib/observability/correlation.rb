require "securerandom"
require "active_support/isolated_execution_state"

module Observability
  # The identifier that ties a request to the jobs it starts. It lives outside
  # autoloaded code because the log formatter also runs during boot.
  module Correlation
    KEY = :observability_correlation_id

    def self.id
      ActiveSupport::IsolatedExecutionState[KEY]
    end

    def self.with(id)
      previous = self.id
      ActiveSupport::IsolatedExecutionState[KEY] = id
      yield
    ensure
      ActiveSupport::IsolatedExecutionState[KEY] = previous
    end

    def self.generate
      SecureRandom.uuid
    end
  end
end

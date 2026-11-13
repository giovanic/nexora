module Shared
  module Outbox
    # Proof that a consumer applied an event. Its primary key (consumer, event_id)
    # makes a second delivery a no-op.
    class ConsumedEvent < ApplicationRecord
      self.table_name = "consumed_events"
      self.primary_key = %i[consumer event_id]
    end
  end
end

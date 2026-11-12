module Identity
  # Append-only. RecordAudit is the only writer and enforces the closed list
  # of metadata per action.
  class AuditEvent < ApplicationRecord
    self.table_name = "audit_events"

    def readonly?
      persisted? || super
    end
  end
end

module Identity
  # One per account whose deletion was requested (design 4.4). RequestDeletion
  # writes it and EraseAccountJob marks each context done. It outlives the
  # erasure as the record for backup restores: only the UUID and the dates.
  class AccountDeletion < ApplicationRecord
    self.table_name = "account_deletions"
  end
end

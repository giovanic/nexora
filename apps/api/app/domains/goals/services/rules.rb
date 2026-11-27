module Goals
  # Completion rules, one per version. A version already in use is never removed or changed:
  # a new rule gets a new key, and goals keep the version they were created with.
  module Rules
    class UnknownVersion < StandardError; end

    # daily_any_v1: a day is complete when there is at least one check-in on that local date.
    TABLE = {
      "daily_any_v1" => ->(check_ins, local_date) { check_ins.any? { |check_in| check_in.local_date == local_date } }
    }.freeze
    CURRENT = "daily_any_v1".freeze

    def self.fetch(version)
      TABLE.fetch(version) { raise UnknownVersion, "unknown rule version" }
    end
  end
end

module Goals
  # Pure: whether a day is complete under a rule version. check_ins is any list whose items answer local_date.
  module EvaluateDay
    def self.call(rule_version:, local_date:, check_ins:)
      Rules.fetch(rule_version).call(check_ins, local_date) ? true : false
    end
  end
end

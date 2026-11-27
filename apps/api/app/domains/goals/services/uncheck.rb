module Goals
  # Removes the manual check-in of a day. A check-in from a meal stays, so the day may remain done. Without a manual
  # check-in nothing changes. DayInfo, :not_found or Errors.
  module Uncheck
    def self.call(user_id:, goal_id:, local_date:)
      DayChange.call(user_id:, goal_id:, local_date:) do |goal, date|
        goal.check_ins.where(local_date: date, source: "manual").delete_all
      end
    end
  end
end

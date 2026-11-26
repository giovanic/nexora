module Goals
  # The only entry point to Goals for other contexts and controllers. It returns Data objects, never models.
  module Api
    USER_DATA_TABLES = %w[goals goal_check_ins].freeze

    # created: only from create_goal, false when the person already had a live goal of the type.
    GoalInfo = Data.define(:id, :goal_type, :status, :starts_on, :ends_on, :done_today, :done_yesterday, :created) do
      def initialize(id:, goal_type:, status:, starts_on:, ends_on:, done_today:, done_yesterday:, created: false) = super
      def ok? = true
    end
    # code: validation_failed (details name the field and code) or goal_not_active.
    Errors = Data.define(:code, :details) do
      def ok? = false
    end

    # sources: the check-in sources of the day, ordered and without repeats (manual, food_entry).
    DayInfo = Data.define(:goal_id, :local_date, :done, :sources) do
      def ok? = true
    end

    class << self
      def goal_types = GoalType::ALL

      # GoalInfo (created says whether it is new) or Errors validation_failed.
      def create_goal(user_id:, goal_type:)
        CreateGoal.call(user_id:, goal_type:)
      end

      # status: active, paused or ended. GoalInfo, :not_found (also another person's goal or a malformed id) or
      # Errors: validation_failed, goal_not_active (an ended goal is final).
      def change_status(user_id:, goal_id:, status:)
        ChangeStatus.call(user_id:, goal_id:, status:)
      end

      # :deleted (the check-ins go with it) or :not_found.
      def delete_goal(user_id:, goal_id:)
        DeleteGoal.call(user_id:, goal_id:)
      end

      # Marks the day done by hand, for today or yesterday (a String YYYY-MM-DD or a Date). DayInfo, :not_found or Errors:
      # validation_failed (local_date: invalid, outside_window) or goal_not_active. Repeating it changes nothing.
      def check_in(user_id:, goal_id:, local_date:)
        CheckIn.call(user_id:, goal_id:, local_date:)
      end

      # Removes the manual check-in; one from a meal stays. Same results as check_in.
      def uncheck(user_id:, goal_id:, local_date:)
        Uncheck.call(user_id:, goal_id:, local_date:)
      end

      def export_user_data(user_id)
        UserData.export(user_id)
      end

      def erase_user_data(user_id)
        UserData.erase(user_id)
      end
    end
  end
end

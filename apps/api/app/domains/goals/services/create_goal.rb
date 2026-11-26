module Goals
  # Starts a daily goal of an allowed type. The person has at most one live (active or paused) goal per type: asking
  # again returns it with created false, also when two requests race (the unique index decides, the loser re-reads).
  # goal.created (identifier and type) goes to the outbox in the same transaction.
  module CreateGoal
    def self.call(user_id:, goal_type:)
      unless GoalType.allowed?(goal_type)
        return Api::Errors.new(code: "validation_failed", details: [ { field: "goal_type", code: "unsupported_goal_type" } ])
      end

      yesterday, today = LocalDay.window(user_id:)
      begin
        goal, created = find_or_create(user_id:, goal_type:, today:)
      rescue ActiveRecord::RecordNotUnique
        goal = live(user_id, goal_type)
        created = false
      end
      GoalView.call(goal, today:, yesterday:, created:)
    end

    def self.find_or_create(user_id:, goal_type:, today:)
      Goal.transaction(requires_new: true) do
        existing = live(user_id, goal_type)
        next [ existing, false ] if existing

        goal = Goal.create!(user_id:, goal_type:, rule_version: Rules::CURRENT, starts_on: today)
        Shared::Outbox.publish!(name: "goal.created", user_id:, payload: { goal_id: goal.id, goal_type: goal.goal_type })
        [ goal, true ]
      end
    end

    def self.live(user_id, goal_type) = Goal.find_by(user_id:, goal_type:, status: Goal::LIVE)
  end
end

module Goals
  # Deletes the goal and its check-ins for good; goal.deleted (identifier only) goes to the outbox in the same
  # transaction. :deleted or :not_found (also another person's goal).
  module DeleteGoal
    def self.call(user_id:, goal_id:)
      Goal.transaction do
        goal = Goal.owned(user_id, goal_id, lock: true)
        next :not_found unless goal

        goal.destroy!
        Shared::Outbox.publish!(name: "goal.deleted", user_id:, payload: { goal_id: goal.id })
        :deleted
      end
    end
  end
end

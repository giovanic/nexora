module Goals
  # Goals' part of account export and deletion, through Shared::DataRegistry.
  # source_ref stays out of the export: it points into another context's table. The deleted-meal markers
  # (goal_removed_food_entries) stay out too, for the same reason: they hold only the id of a meal of another context.
  module UserData
    def self.export(user_id)
      goals = Goal.where(user_id:).includes(:check_ins).order(:starts_on, :id)
      {
        goals: goals.map do |goal|
          goal.slice(:id, :goal_type, :status, :starts_on, :ends_on, :paused_at, :rule_version).symbolize_keys.merge(
            check_ins: goal.check_ins.sort_by { |c| [ c.local_date, c.id ] }.map do |check_in|
              check_in.slice(:local_date, :source, :checked_at).symbolize_keys
            end
          )
        end
      }
    end

    # Check-ins go with their goals (ON DELETE CASCADE); the markers are deleted by owner, with or without a goal.
    # Safe to run again. A food_entry.deleted that commits after this (the users row is only soft-deleted, so no
    # cascade) can leave one marker: it holds only ids and the 30-day retention job removes it.
    def self.erase(user_id)
      Goal.transaction do
        RemovedFoodEntry.where(user_id:).delete_all
        Goal.where(user_id:).delete_all
      end
    end
  end
end

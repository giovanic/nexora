module Nutrition
  # Takes an item out of the meal and recalculates it. The row is kept, hidden as removed, not deleted.
  # The meal, :not_found (also for another person's meal or item, or an item already hidden) or Errors
  # (entry_not_editable).
  module RemoveFoodItem
    def self.call(user_id:, food_entry_id:, item_id:)
      EditableEntry.with(user_id:, food_entry_id:) do |entry|
        item = entry.visible_items.find_by(id: item_id)
        next :not_found unless item

        item.update!(hidden_at: Time.current, hidden_reason: "removed")
        RecalculateEntry.call(entry)
      end
    end
  end
end

# Goals' tables in account export and deletion.
Rails.application.config.to_prepare do
  Shared::DataRegistry.register(
    context: "goals",
    tables: Goals::Api::USER_DATA_TABLES,
    exporter: Goals::Api.method(:export_user_data),
    eraser: Goals::Api.method(:erase_user_data)
  )

  # A confirmed meal completes the day of the active log_meals goal; a deleted meal undoes it.
  Shared::Outbox.subscribe("food_entry.confirmed", consumer: "goals.check_in_from_food_entry") { |event| Goals::CheckInFromFoodEntry.call(event) }
  Shared::Outbox.subscribe("food_entry.deleted", consumer: "goals.remove_food_entry_check_in") { |event| Goals::RemoveFoodEntryCheckIn.call(event) }
end

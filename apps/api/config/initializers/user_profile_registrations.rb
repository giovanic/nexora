# UserProfile's consumer of user.registered and its tables in account export and deletion.
Rails.application.config.to_prepare do
  Shared::Outbox.subscribe("user.registered", consumer: "user_profile.create_profile") { |event| UserProfile::CreateProfile.call(event) }

  Shared::DataRegistry.register(
    context: "user_profile",
    tables: UserProfile::Api::USER_DATA_TABLES,
    exporter: UserProfile::Api.method(:export_user_data),
    eraser: UserProfile::Api.method(:erase_user_data)
  )
end

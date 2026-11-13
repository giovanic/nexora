# Identity's tables in account export and deletion, and the outbox rule that
# drops the events of an account being deleted (design 4.4).
Rails.application.config.to_prepare do
  Shared::DataRegistry.register(
    context: "identity",
    tables: Identity::Api::USER_DATA_TABLES,
    exporter: Identity::Api.method(:export_user_data),
    eraser: Identity::Api.method(:erase_user_data)
  )

  # From the request on, so a late event never recreates erased data (ruling
  # R4). The check locks the person's row, so a request cannot commit between
  # it and the consumers (ruling R40). The outbox never discards user.deletion_requested itself.
  Shared::Outbox.discard_if { |event| event.user_id.present? && Identity::Api.deletion_requested_for_delivery?(user_id: event.user_id) }
end

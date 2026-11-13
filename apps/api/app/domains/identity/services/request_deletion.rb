module Identity
  # Account deletion (LGPD, design 4.4). The password is asked again. In one
  # transaction every session ends, the deletion records the contexts still to
  # erase, from the registry, and user.deletion_requested goes to the outbox
  # for effects outside the database. EraseAccountJob does the erasure.
  #
  # Asking again for an account already being deleted answers :scheduled and
  # writes nothing; the unique index on user_id settles two requests at once.
  module RequestDeletion
    def self.call(user_id:, password:, ip:)
      return :scheduled if AccountDeletion.exists?(user_id:)
      return :invalid_password unless Api.verify_password(user_id:, password:)

      deletion = create(user_id, ip)
      ActiveRecord.after_all_transactions_commit { enqueue(deletion.id) } if deletion
      :scheduled
    rescue ActiveRecord::RecordNotUnique => conflict
      raise unless conflict.message.include?("index_account_deletions_on_user_id")

      :scheduled
    end

    def self.create(user_id, ip)
      AccountDeletion.transaction do
        next unless User.active.lock.find_by(id: user_id)

        RevokeSession.all(user_id:)
        deletion = AccountDeletion.create!(user_id:, requested_at: Time.current, pending_contexts: Shared::DataRegistry.contexts)
        RecordAudit.call(action: "account_deletion_requested", user_ref: user_id, ip:)
        Shared::Outbox.publish!(name: Shared::Outbox::DELETION_REQUESTED, user_id:)
        deletion
      end
    end

    # After every commit, so the job finds the row. DeletionDeadlineJob enqueues
    # it again every hour, so a lost enqueue only delays the erasure.
    def self.enqueue(deletion_id)
      EraseAccountJob.perform_async(deletion_id)
    rescue StandardError => error
      # The message can name the queue host, so only the class goes to the log.
      Rails.logger.warn("account erasure not enqueued, the hourly check enqueues it account_deletion_id=#{deletion_id} error=#{error.class}")
    end

    private_class_method :create, :enqueue
  end
end

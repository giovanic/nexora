module Identity
  # Erases an account (design 4.4): runs the registry's eraser of every
  # context still pending, each in its own transaction, and marks it done. A
  # failing one does not hold back the others; the job fails at the end and
  # Sidekiq retries it, skipping the contexts already done. Once none is
  # pending, the users row is anonymized: same UUID, a random e-mail, no usable
  # password and deleted_at. Identity names no other context: it only walks
  # Shared::DataRegistry. It receives the deletion id, never the user's data.
  class EraseAccountJob
    include Sidekiq::Job

    # Raised when an eraser failed, so Sidekiq retries. It carries no message.
    class Incomplete < StandardError; end

    def perform(account_deletion_id)
      deletion = AccountDeletion.find_by(id: account_deletion_id)
      return if deletion.nil? || deletion.completed_at

      erasers = Shared::DataRegistry.erasers.to_h
      failed = deletion.pending_contexts.reject { |context| erase(deletion, context, erasers[context]) }
      raise Incomplete if failed.any?

      anonymize(deletion)
    end

    private

    # Locks the deletion, so two runs at once never erase the same context twice.
    def erase(deletion, context, eraser)
      AccountDeletion.transaction do
        deletion.lock!
        next true unless deletion.pending_contexts.include?(context)
        raise KeyError, "no eraser registered" unless eraser

        eraser.call(deletion.user_id)
        deletion.update!(pending_contexts: deletion.pending_contexts - [ context ])
      end
      true
    rescue StandardError => error
      # The message can carry user data, so only identifiers and the class go to the log.
      Rails.logger.warn("account erasure failed account_deletion_id=#{deletion.id} context=#{context} error=#{error.class}")
      false
    end

    # update_all writes without reading the old values, so it never decrypts the
    # e-mail; the new one is still encrypted, keeping the NOT NULL and the
    # unique index. The digest, made as for any password, is of a random
    # secret nobody keeps.
    def anonymize(deletion)
      AccountDeletion.transaction do
        deletion.lock!
        next if deletion.completed_at || deletion.pending_contexts.any?

        now = Time.current
        User.where(id: deletion.user_id).update_all(
          email: "deleted-#{SecureRandom.uuid}@deleted.invalid",
          password_digest: User.new(password: SecureRandom.hex(32)).password_digest,
          deleted_at: now, updated_at: now
        )
        deletion.update!(completed_at: now)
      end
    end
  end
end

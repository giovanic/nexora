module Identity
  # Daily (config/schedule.yml). Removes Identity's own data that is past its
  # period (DATABASE_DESIGN.md, "Retenção"; the periods are provisional until
  # the legal review):
  #
  # - sessions: 30 days after they expired or were revoked;
  # - audit_events: 5 years;
  # - consent_records: 5 years, except the latest record of each purpose of a
  #   live account, which is the proof of what that account holds today.
  #
  # account_deletions needs no step: it already keeps only the UUID and the
  # dates, and it stays as the record for backup restores.
  #
  # Each table goes in batches, so no statement locks a large range, and a
  # second run finds nothing left. Outbox tables belong to shared/, which has
  # its own job. The log line carries counts only.
  class RetentionJob
    include Sidekiq::Job

    sidekiq_options retry: false

    BATCH = 1_000
    SESSION_GRACE = 30.days
    PROOF_PERIOD = 5.years

    def perform
      now = Time.current
      result = {
        sessions: delete_in_batches(past_sessions(now - SESSION_GRACE)),
        audit_events: delete_in_batches(AuditEvent.where(occurred_at: ...(now - PROOF_PERIOD))),
        consent_records: delete_in_batches(superseded_consents(now - PROOF_PERIOD)) + delete_in_batches(consents_of_deleted_accounts(now - PROOF_PERIOD))
      }
      Sidekiq.logger.info("identity retention #{result.map { |table, count| "#{table}=#{count}" }.join(' ')}")
      result
    end

    private

    def past_sessions(cutoff)
      Session.where(revoked_at: ..cutoff)
        .or(Session.where("LEAST(sessions.idle_expires_at, sessions.absolute_expires_at) <= ?", cutoff))
    end

    def superseded_consents(cutoff)
      ConsentRecord.where(occurred_at: ...cutoff).where(<<~SQL.squish)
        EXISTS (SELECT 1 FROM consent_records newer
                WHERE newer.user_id = consent_records.user_id AND newer.purpose = consent_records.purpose
                  AND newer.occurred_at > consent_records.occurred_at)
      SQL
    end

    def consents_of_deleted_accounts(cutoff)
      ConsentRecord.where(occurred_at: ...cutoff).where(user_id: User.where.not(deleted_at: nil).select(:id))
    end

    def delete_in_batches(scope)
      total = 0
      scope.in_batches(of: BATCH) { |batch| total += batch.delete_all }
      total
    end
  end
end

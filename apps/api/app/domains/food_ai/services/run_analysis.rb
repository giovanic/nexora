module FoodAi
  # One step of the analysis pipeline for one photo (design 4.2 to 4.4). The job calls it with the
  # attempts already made; it answers a Retry when the job must run again later, and nil when done.
  #
  # Locking: the photo row is locked (FOR UPDATE) only in short transactions that claim the run,
  # check before the call, and write the outcome. Storage and the provider are never called inside
  # one, and no lock is held while waiting. The partial unique index on (photo_id, prompt_version)
  # is the last defence against two jobs claiming the same run.
  #
  # Nothing the model or the photo held reaches a log or an error: only identifiers and codes.
  class RunAnalysis
    MAX_TRANSIENT_ATTEMPTS = 3
    MAX_INVALID_RETRIES = 1
    # A run that stays running this long belongs to a job that died, and may be taken over.
    STALE_AFTER = 10.minutes
    BASE_DELAY = 15
    INVALID_DELAY = 5
    LIVE_STATUSES = %w[succeeded no_food unreadable].freeze
    OUTCOMES = { "succeeded" => "analyzed", "no_food" => "no_food", "unreadable" => "unreadable" }.freeze

    Retry = Data.define(:delay, :transient_attempts, :invalid_attempts)
    Run = Data.define(:analysis_id, :photo_id, :user_id, :object_key, :content_type, :prompt)
    # An object to delete after the transaction. The row may be gone, so the key travels with it.
    Purge = Data.define(:photo_id, :object_key)

    class << self
      def call(photo_id:, transient_attempts: 0, invalid_attempts: 0)
        new(photo_id:, transient_attempts:, invalid_attempts:).call
      end

      # Exponential, with jitter, for the nth failed attempt (1-based).
      def backoff(attempt, base: BASE_DELAY)
        (base * (2**(attempt - 1))) + rand(0..(base / 2.0))
      end

      # The job ran out of its own retries after unexpected errors: end it as failed.
      def give_up(photo_id:)
        new(photo_id:).give_up
      end

      # Publishes food_analysis.completed. Inside the caller's transaction.
      def publish_completed(user_id:, analysis_id:, food_entry_id:, outcome:, error_code: nil)
        Shared::Outbox.publish!(name: "food_analysis.completed", user_id:, version: 1,
                                payload: { analysis_id:, food_entry_id:, outcome:, error_code: })
      end
    end

    def initialize(photo_id:, transient_attempts: 0, invalid_attempts: 0)
      @photo_id = photo_id
      @transient_attempts = transient_attempts
      @invalid_attempts = invalid_attempts
      @purge = []
    end

    def call
      run = claim
      result = run.is_a?(Run) ? execute(run) : nil
      purge_objects
      result
    end

    def give_up
      FoodPhoto.transaction do
        photo = FoodPhoto.lock.find_by(id: @photo_id)
        next unless photo&.status == "stored" && photo.quota_refunded_at.nil?

        prompt = PromptCatalog.current
        # An analysis that already concluded, or a run another job still owns, must not be failed
        # (the error that exhausted the retries may have come after the result was saved).
        live = AnalysisResult.where(photo_id: photo.id, prompt_version: prompt.version).where.not(status: %w[failed cancelled]).first
        next if live && (LIVE_STATUSES.include?(live.status) || live.updated_at >= STALE_AFTER.ago)

        live&.update!(status: "failed", error_code: "internal_error", finished_at: Time.current)
        analysis = live || new_analysis(photo, prompt, status: "failed", error_code: "internal_error", finished_at: Time.current)
        finish_failed(photo, analysis)
      end
    end

    private

    # Short transaction: the photo is locked, and either a run is created, or the job learns
    # there is nothing to do (done, running elsewhere, cancelled).
    def claim
      FoodPhoto.transaction do
        photo = FoodPhoto.lock.find_by(id: @photo_id)
        # quota_refunded_at marks a run that ended in failure: a new request clears it.
        next unless photo&.status == "stored" && photo.quota_refunded_at.nil?

        prompt = PromptCatalog.current
        live = AnalysisResult.lock.where(photo_id: photo.id, prompt_version: prompt.version).where.not(status: %w[failed cancelled]).first
        if live
          # Only a succeeded run gets here still stored: no_food and unreadable delete the photo, which ends the claim above.
          next republish(live) if LIVE_STATUSES.include?(live.status)
          next unless live.updated_at < STALE_AFTER.ago

          live.update!(status: "failed", error_code: "timeout", finished_at: Time.current)
        end
        next cancel(photo, new_analysis(photo, prompt, status: "cancelled", error_code: "consent_revoked", finished_at: Time.current)) if refused?(photo)

        analysis = new_analysis(photo, prompt, status: "running")
        Run.new(analysis_id: analysis.id, photo_id: photo.id, user_id: photo.user_id, object_key: photo.object_key, content_type: photo.content_type, prompt:)
      end
    rescue ActiveRecord::RecordNotUnique
      nil # another job claimed this run first
    end

    def execute(run)
      normalized = prepare(run)
      return normalized unless normalized.is_a?(NormalizedPhoto)

      return unless guard(run)

      begin
        response = FoodAi.adapter.analyze(image: normalized.bytes, content_type: normalized.content_type, prompt: run.prompt, schema: run.prompt.schema)
        # The answer is paid for: its cost is recorded in a transaction of its own, before anything that can fail.
        record_usage(run, response)
        output = ValidateOutput.call(response.payload)
      rescue TransientProviderError => error
        return failed(run, error.code, kind: :transient)
      rescue InvalidOutputError => error
        return failed(run, error.code, kind: :invalid)
      rescue PermanentProviderError => error
        return failed(run, error.code, kind: :permanent)
      end
      persist(run, response, output)
    # Sidekiq::Shutdown is an Interrupt, not a StandardError: without it a run would stay running until it goes stale.
    rescue StandardError, Sidekiq::Shutdown => error
      release(run, error)
      raise
    end

    # Reads, normalizes and replaces the object. Returns the photo, or the outcome of a failure.
    def prepare(run)
      bytes = FoodAi.storage.read(key: run.object_key)
      return failed(run, "photo_missing", kind: :permanent) if bytes.nil?

      normalized = NormalizePhoto.call(bytes:, declared_type: run.content_type)
      # The meal may have been erased since the claim: the copy must not be written back.
      return abandon(run) unless FoodPhoto.exists?(id: run.photo_id, status: "stored")

      FoodAi.storage.write(key: run.object_key, bytes: normalized.bytes, content_type: normalized.content_type)
      # The stored object is now the normalized one; the record follows it, so a retry reads it as it is.
      FoodPhoto.where(id: run.photo_id).update_all(content_type: normalized.content_type, byte_size: normalized.bytes.bytesize, updated_at: Time.current)
      normalized
    rescue InvalidPhotoError
      failed(run, "invalid_photo", kind: :permanent)
    end

    # The photo is gone or deleted: nothing is written or called. Its object, if the row says deleted, is purged.
    def abandon(run)
      settle(run) { nil }
      nil
    end

    # Right before the provider call: the meal may be gone and the consent revoked. True to go on.
    def guard(run)
      go = false
      settle(run) do |photo, analysis|
        if refused?(photo)
          cancel(photo, analysis)
        else
          go = true
        end
      end
      go
    end

    def persist(run, response, output)
      settle(run) do |photo, analysis|
        next cancel(photo, analysis) if refused?(photo)

        status = status_for(output)
        attributes = { status:, provider: response.provider, model: response.model, finished_at: Time.current }
        attributes[:raw_response] = output.to_h if status == "succeeded"
        analysis.update!(**attributes)
        if status == "succeeded"
          photo.update!(analyzed_at: Time.current)
        else
          discard(photo) # no food or unreadable: the photo may show a document or a person
        end
        complete(photo, analysis, OUTCOMES.fetch(status))
        log("analysis finished", analysis, outcome: OUTCOMES.fetch(status))
      end
      nil
    end

    def status_for(output)
      return "unreadable" if output.image_quality == "unreadable"
      return "no_food" unless output.contains_food

      output.items.empty? ? "unreadable" : "succeeded"
    end

    # Retry or finish the run as failed.
    def failed(run, code, kind:, response: nil)
      retry_step = next_attempt(kind)
      settle(run) do |photo, analysis|
        analysis.update!(status: "failed", error_code: code, finished_at: Time.current)
        # The original was never normalized, so it still has its EXIF and GPS: it goes now, like a photo with no food.
        discard(photo) if code == "invalid_photo"
        if retry_step
          log("analysis will retry", analysis, error_code: code)
        else
          finish_failed(photo, analysis)
        end
      end
      retry_step if @settled
    end

    def next_attempt(kind)
      case kind
      when :transient
        attempts = @transient_attempts + 1
        attempts < MAX_TRANSIENT_ATTEMPTS ? Retry.new(delay: self.class.backoff(attempts), transient_attempts: attempts, invalid_attempts: @invalid_attempts) : nil
      when :invalid
        @invalid_attempts < MAX_INVALID_RETRIES ? Retry.new(delay: self.class.backoff(1, base: INVALID_DELAY), transient_attempts: @transient_attempts, invalid_attempts: @invalid_attempts + 1) : nil
      end
    end

    def finish_failed(photo, analysis)
      photo.update!(quota_refunded_at: Time.current) if photo.quota_refunded_at.nil?
      complete(photo, analysis, "failed", error_code: analysis.error_code)
      log("analysis failed", analysis, error_code: analysis.error_code)
    end

    # Locks the photo and the run, and yields only while the
    # run is still this job's. Otherwise the result is dropped: the meal was erased or the run was
    # cancelled meanwhile, and nothing is recreated. @settled tells whether the block ran.
    def settle(run)
      @settled = false
      FoodPhoto.transaction do
        photo = FoodPhoto.lock.find_by(id: run.photo_id)
        analysis = AnalysisResult.lock.find_by(id: run.analysis_id)
        if photo.nil? || photo.status != "stored" || analysis.nil? || analysis.status != "running"
          # The normalized copy may have been written after the meal's object was deleted (or its row erased).
          @purge << Purge.new(photo&.id, run.object_key) if photo.nil? || photo.status == "deleted"
          next
        end

        @settled = true
        yield photo, analysis
      end
    end

    # Its own short transaction. The cost is kept even when the meal, the analysis or the person is gone,
    # unlinked from whatever no longer exists (the person's id must not outlive their rows).
    def record_usage(run, response)
      attributes = { provider: response.provider, model: response.model, input_tokens: response.input_tokens,
                     output_tokens: response.output_tokens, cost_usd: response.cost_usd, occurred_at: Time.current }
      begin
        UsageRecord.transaction do
          UsageRecord.create!(**attributes, analysis_id: (run.analysis_id if AnalysisResult.exists?(id: run.analysis_id)),
                                            user_id: (run.user_id if FoodPhoto.exists?(id: run.photo_id)))
        end
      rescue ActiveRecord::InvalidForeignKey
        UsageRecord.create!(**attributes, analysis_id: nil, user_id: nil)
      end
    end

    def new_analysis(photo, prompt, **attributes)
      AnalysisResult.create!(photo_id: photo.id, user_id: photo.user_id, food_entry_id: photo.food_entry_id,
                             provider: Config.provider || "unknown", model: Config.model || "unknown",
                             prompt_version: prompt.version, schema_version: prompt.schema_version, started_at: Time.current, **attributes)
    end

    # Any refusal of the consent that must stand at this moment (revoked, outdated version, another operator
    # or region, health_data gone), or an account deletion in progress, cancels like a revocation.
    def refused?(photo)
      ConsentGate.check_for_job(user_id: photo.user_id) || Identity::Api.deletion_requested?(user_id: photo.user_id)
    end

    # The analysis is cancelled, the result dropped, the photo deleted.
    def cancel(photo, analysis)
      analysis.update!(status: "cancelled", error_code: "consent_revoked", raw_response: nil, finished_at: Time.current)
      discard(photo)
      complete(photo, analysis, "cancelled", error_code: "consent_revoked")
      log("analysis cancelled", analysis, error_code: "consent_revoked")
      nil
    end

    def discard(photo)
      photo.update!(status: "deleted", deleted_at: Time.current)
      @purge << Purge.new(photo.id, photo.object_key)
    end

    def complete(photo, analysis, outcome, error_code: nil)
      self.class.publish_completed(user_id: photo.user_id, analysis_id: analysis.id, food_entry_id: photo.food_entry_id, outcome:, error_code:)
    end

    # The run finished earlier; a delivery that did not happen yet is sent again (consumers are idempotent).
    def republish(analysis)
      payload = { analysis_id: analysis.id, outcome: OUTCOMES.fetch(analysis.status) }
      unless Shared::Outbox.undelivered?(name: "food_analysis.completed", user_id: analysis.user_id, payload:)
        return nil
      end

      self.class.publish_completed(user_id: analysis.user_id, analysis_id: analysis.id, food_entry_id: analysis.food_entry_id, outcome: payload[:outcome])
      nil
    end

    # An unexpected failure: free the run so the next attempt can claim it, and let Sidekiq retry.
    def release(run, error)
      AnalysisResult.where(id: run.analysis_id, status: "running").update_all(status: "failed", error_code: "internal_error", finished_at: Time.current, updated_at: Time.current)
      Rails.logger.warn("analysis aborted analysis_id=#{run.analysis_id} error=#{error.class}")
    rescue StandardError
      nil
    end

    # Outside any transaction. A failure queues the deletion again instead of failing the job.
    def purge_objects
      @purge.uniq(&:object_key).each do |target|
        FoodAi.storage.delete(key: target.object_key)
      rescue StandardError
        # With the row gone there is nothing to retry from: the retention sweep of the bucket is the net.
        PurgeObjectJob.perform_async(target.photo_id) if target.photo_id
      end
      @purge = []
    end

    def log(message, analysis, **fields)
      details = fields.map { |name, value| " #{name}=#{value}" }.join
      Rails.logger.info("food #{message} analysis_id=#{analysis.id}#{details}")
    end
  end
end

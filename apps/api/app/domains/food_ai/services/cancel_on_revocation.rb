module FoodAi
  # Consumer of consent.revoked. When the purpose is food_photo_ai, discards the photos of that
  # person that have no concluded analysis (awaiting upload, stored, or being analyzed), cancels the
  # run in progress, and tells each linked meal with a cancelled outcome. It runs inside the outbox
  # transaction, so it writes only to the database; the objects are deleted by a job after commit.
  # Safe to deliver again: a deleted photo is not touched twice.
  module CancelOnRevocation
    PURPOSE = "food_photo_ai".freeze

    def self.call(event)
      return unless event.payload["purpose"] == PURPOSE

      FoodPhoto.where(user_id: event.user_id, status: %w[awaiting_upload stored]).order(:id).lock.each do |photo|
        next if AnalysisResult.where(photo_id: photo.id, status: RunAnalysis::LIVE_STATUSES).exists?

        cancel_photo(photo)
      end
    end

    # Cancels the run in progress, deletes the photo, tells its meal, and queues the object deletion after
    # the commit. Inside the caller's transaction, with the photo locked.
    def self.cancel_photo(photo)
      running = AnalysisResult.lock.find_by(photo_id: photo.id, status: "running")
      running&.update!(status: "cancelled", error_code: "consent_revoked", raw_response: nil, finished_at: Time.current)
      photo.update!(status: "deleted", deleted_at: Time.current)
      if photo.food_entry_id
        RunAnalysis.publish_completed(user_id: photo.user_id, analysis_id: running&.id, food_entry_id: photo.food_entry_id,
                                      outcome: "cancelled", error_code: "consent_revoked")
      end
      FoodPhoto.current_transaction.after_commit { PurgeObjectJob.perform_async(photo.id) }
    end
  end
end

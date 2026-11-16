module FoodAi
  # Consumer of food_entry.deleted. Erases what the meal left in FoodAi: its photo (marked deleted, object
  # deleted by a job after the commit), its analyses, and the link of the cost records to them. It runs inside
  # the outbox transaction, so it writes only to the database. It is the net under the synchronous erasure
  # Nutrition also tries (PhotoCleanup.erase_for_entry): safe to deliver again, and another person's photo is
  # never touched (the event's user_id scopes every query).
  module EraseOnEntryDeleted
    def self.call(event)
      payload = event.payload
      photos = FoodPhoto.where(user_id: event.user_id)
      photos = payload["photo_id"] ? photos.where(food_entry_id: payload["food_entry_id"]).or(photos.where(id: payload["photo_id"])) : photos.where(food_entry_id: payload["food_entry_id"])
      photos.order(:id).lock.each do |photo|
        analysis_ids = AnalysisResult.where(photo_id: photo.id).pluck(:id)
        UsageRecord.where(analysis_id: analysis_ids).update_all(analysis_id: nil, updated_at: Time.current)
        AnalysisResult.where(id: analysis_ids).delete_all
        photo.update!(status: "deleted", deleted_at: Time.current) unless photo.status == "deleted"
        FoodPhoto.current_transaction.after_commit { PurgeObjectJob.perform_async(photo.id) }
      end
    end
  end
end

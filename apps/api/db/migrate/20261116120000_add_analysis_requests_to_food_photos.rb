# How many times the photo was handed to the analysis (the first request and every new one after a failure).
# It caps new requests per photo, and tells an upload that was abandoned (0) from one that was used.
class AddAnalysisRequestsToFoodPhotos < ActiveRecord::Migration[8.1]
  def change
    add_column :food_photos, :analysis_requests, :integer, null: false, default: 0
    add_check_constraint :food_photos, "analysis_requests >= 0", name: "food_photos_analysis_requests_non_negative"
  end
end

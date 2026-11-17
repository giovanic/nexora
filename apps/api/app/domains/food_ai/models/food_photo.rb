module FoodAi
  # A meal photo and the life of its object in private storage. The object_key is random
  # and never logged. Services on it (authorization, deletion) arrive with the upload task.
  class FoodPhoto < ApplicationRecord
    self.table_name = "food_photos"

    STATUSES = %w[awaiting_upload stored deleted].freeze

    validates :status, inclusion: { in: STATUSES }
    validates :client_request_id, :object_key, :content_type, :authorized_at, presence: true
    validates :object_key, uniqueness: true
    validates :client_request_id, uniqueness: { scope: :user_id }
  end
end

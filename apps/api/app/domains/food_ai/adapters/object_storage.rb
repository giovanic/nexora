module FoodAi
  module Adapters
    # Interface of the private object storage (ADR 0019). Keys, signed URLs and
    # credentials never go in logs or exception messages.
    class ObjectStorage
      MAX_EXPIRES_IN = 900

      PresignedUpload = Data.define(:url, :headers, :expires_at)
      ObjectInfo = Data.define(:byte_size, :content_type)

      def presigned_put(key:, content_type:, byte_size:, expires_in: MAX_EXPIRES_IN) = raise(NotImplementedError)
      def presigned_get(key:, expires_in: MAX_EXPIRES_IN) = raise(NotImplementedError)
      def head(key:) = raise(NotImplementedError)
      def read(key:) = raise(NotImplementedError)
      def write(key:, bytes:, content_type:) = raise(NotImplementedError)
      def delete(key:) = raise(NotImplementedError)

      private

      def check_expiry!(expires_in)
        return if expires_in.is_a?(Integer) && expires_in.between?(1, MAX_EXPIRES_IN)

        raise ArgumentError, "expires_in must be between 1 and #{MAX_EXPIRES_IN} seconds"
      end
    end
  end
end

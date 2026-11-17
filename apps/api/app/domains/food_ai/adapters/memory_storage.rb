module FoodAi
  module Adapters
    # In-process double for the common suite. No network.
    class MemoryStorage < ObjectStorage
      def initialize
        super
        @objects = {}
      end

      def presigned_put(key:, content_type:, byte_size:, expires_in: MAX_EXPIRES_IN)
        check_expiry!(expires_in)
        PresignedUpload.new(
          url: "memory://upload/#{key}",
          headers: { "Content-Type" => content_type, "Content-Length" => byte_size.to_s },
          expires_at: Time.current + expires_in
        )
      end

      def presigned_get(key:, expires_in: MAX_EXPIRES_IN)
        check_expiry!(expires_in)
        "memory://download/#{key}"
      end

      def head(key:)
        object = @objects[key]
        object && ObjectInfo.new(byte_size: object[:bytes].bytesize, content_type: object[:content_type])
      end

      def read(key:) = @objects[key]&.fetch(:bytes)

      def write(key:, bytes:, content_type:)
        @objects[key] = { bytes: bytes.b, content_type: content_type }
        nil
      end

      def delete(key:)
        @objects.delete(key)
        nil
      end
    end
  end
end

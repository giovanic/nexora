require "aws-sdk-s3"

module FoodAi
  module Adapters
    # S3-compatible storage (SeaweedFS in development). Provider errors are
    # not wrapped: aws-sdk messages carry no key or signature, and none is added here.
    class S3Storage < ObjectStorage
      # Local defaults match docker-compose.yml, so development and test need no .env.
      # They apply only outside production, which requires the credentials, bucket and
      # region (lib/required_env.rb). An empty variable counts as absent.
      def self.from_env(env: ENV)
        local = !Rails.env.production?
        setting = lambda do |name, default|
          value = env[name].to_s.strip
          value.empty? ? (local ? default : nil) : value
        end
        client = Aws::S3::Client.new(
          region: setting.call("STORAGE_REGION", "us-east-1"),
          endpoint: setting.call("STORAGE_ENDPOINT", "http://127.0.0.1:8334"),
          access_key_id: setting.call("STORAGE_ACCESS_KEY_ID", "app_dev_access_key"),
          secret_access_key: setting.call("STORAGE_SECRET_ACCESS_KEY", "app_dev_secret_key_0123456789"),
          force_path_style: true,
          request_checksum_calculation: "when_required",
          response_checksum_validation: "when_required"
        )
        new(client: client, bucket: setting.call("STORAGE_BUCKET", "app-dev-photos"), create_bucket: local)
      end

      # create_bucket: the bucket is created on first use if missing (development and
      # test only, where nothing else creates it after docker compose up).
      def initialize(client:, bucket:, create_bucket: false)
        super()
        @client = client
        @bucket = bucket
        @create_bucket = create_bucket
        @presigner = Aws::S3::Presigner.new(client: client)
      end

      def presigned_put(key:, content_type:, byte_size:, expires_in: MAX_EXPIRES_IN)
        check_expiry!(expires_in)
        ensure_bucket!
        url, headers = @presigner.presigned_request(
          :put_object, bucket: @bucket, key: key, content_type: content_type, content_length: byte_size,
          expires_in: expires_in,
          # The SDK leaves content-length unsigned by default; signing it makes the storage refuse another size.
          whitelist_headers: %w[content-length]
        )
        PresignedUpload.new(
          url: url,
          headers: { "Content-Type" => content_type, "Content-Length" => byte_size.to_s }.merge(headers || {}),
          expires_at: Time.current + expires_in
        )
      end

      def presigned_get(key:, expires_in: MAX_EXPIRES_IN)
        check_expiry!(expires_in)
        @presigner.presigned_url(:get_object, bucket: @bucket, key: key, expires_in: expires_in)
      end

      def head(key:)
        response = @client.head_object(bucket: @bucket, key: key)
        ObjectInfo.new(byte_size: response.content_length, content_type: response.content_type)
      rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
        nil
      end

      def read(key:)
        @client.get_object(bucket: @bucket, key: key).body.read.b
      rescue Aws::S3::Errors::NoSuchKey, Aws::S3::Errors::NotFound
        nil
      end

      def write(key:, bytes:, content_type:)
        ensure_bucket!
        @client.put_object(bucket: @bucket, key: key, body: bytes, content_type: content_type)
        nil
      end

      def delete(key:)
        @client.delete_object(bucket: @bucket, key: key)
        nil
      end

      private

      def ensure_bucket!
        return unless @create_bucket && !@bucket_ready

        begin
          @client.head_bucket(bucket: @bucket)
        rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchBucket
          @client.create_bucket(bucket: @bucket)
        end
        @bucket_ready = true
      end
    end
  end
end

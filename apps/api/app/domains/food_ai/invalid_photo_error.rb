module FoodAi
  # Carries only a closed-list code. The message is the code, so nothing about the
  # image (bytes, metadata, library error text) can reach a log or an error tracker.
  class InvalidPhotoError < StandardError
    CODES = %w[unsupported_media_type too_large too_many_pixels unreadable_image].freeze

    attr_reader :code

    def initialize(code)
      raise ArgumentError, "unknown code" unless CODES.include?(code.to_s)

      @code = code.to_s
      super(@code)
    end
  end
end

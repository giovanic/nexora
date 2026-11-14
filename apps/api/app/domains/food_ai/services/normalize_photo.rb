require "marcel"
require "vips"

module FoodAi
  # Validates a meal photo by its real bytes and re-encodes it: orientation applied, all
  # metadata (EXIF, GPS, XMP, ICC) dropped, long edge limited, JPEG output.
  # Runs before any AI call (ADR 0019). Never logs bytes or metadata.
  class NormalizePhoto
    ALLOWED_TYPES = %w[image/jpeg image/png image/webp].freeze
    MAX_BYTES = 10 * 1024 * 1024
    MAX_PIXELS = 40_000_000
    MAX_EDGE = 1568
    JPEG_QUALITY = 85

    def self.call(bytes:, declared_type:) = new(bytes, declared_type).call

    def initialize(bytes, declared_type)
      @bytes = bytes.to_s.b
      @declared_type = declared_type.to_s.downcase.strip
    end

    def call
      check_size!
      check_type!
      normalize
    end

    private

    def check_size!
      raise InvalidPhotoError, "too_large" if @bytes.bytesize > MAX_BYTES
    end

    def check_type!
      real = Marcel::MimeType.for(StringIO.new(@bytes)).to_s
      return if ALLOWED_TYPES.include?(real) && real == @declared_type

      raise InvalidPhotoError, "unsupported_media_type"
    end

    def normalize
      # Lazy, sequential open: width and height come from the header only.
      image = Vips::Image.new_from_buffer(@bytes, "", access: :sequential, fail: true)
      raise InvalidPhotoError, "too_many_pixels" if image.width * image.height > MAX_PIXELS

      image = image.autorot
      longest = [ image.width, image.height ].max
      image = image.resize(MAX_EDGE.to_f / longest) if longest > MAX_EDGE
      output = image.jpegsave_buffer(Q: JPEG_QUALITY, strip: true)
      NormalizedPhoto.new(bytes: output, content_type: "image/jpeg", width: image.width, height: image.height)
    rescue Vips::Error
      raise InvalidPhotoError, "unreadable_image"
    end
  end
end

require "vips"

# Synthetic images built at test time with ruby-vips. No real photos, no people.
module ImageFixtures
  module_function

  def solid(width, height, color = [ 200, 120, 40 ])
    Vips::Image.black(width, height).new_from_image(color).copy(interpretation: :srgb).cast(:uchar)
  end

  # A gradient with noise-free structure, so a truncated file really loses data.
  def gradient(width, height)
    x = Vips::Image.xyz(width, height)
    (x[0] * 255.0 / width).bandjoin([ x[1] * 255.0 / height, 90 ]).copy(interpretation: :srgb).cast(:uchar)
  end

  # JPEG with Orientation=6 (needs a 90 degree turn) and GPS tags in the EXIF block.
  def jpeg_with_gps(width: 200, height: 100)
    image = gradient(width, height).mutate do |m|
      m.set_type! GObject::GSTR_TYPE, "exif-ifd0-Orientation", "6 (Right-top, rotate 90 CW)"
      m.set_type! GObject::GSTR_TYPE, "exif-ifd3-GPSLatitudeRef", "S (South)"
      m.set_type! GObject::GSTR_TYPE, "exif-ifd3-GPSLatitude", "23/1 32/1 0/1"
      m.set_type! GObject::GSTR_TYPE, "exif-ifd3-GPSLongitudeRef", "W (West)"
      m.set_type! GObject::GSTR_TYPE, "exif-ifd3-GPSLongitude", "46/1 38/1 0/1"
      m.set_type! GObject::GINT_TYPE, "orientation", 6
    end
    image.jpegsave_buffer(Q: 90)
  end

  def jpeg(width: 200, height: 100)
    gradient(width, height).jpegsave_buffer(Q: 90)
  end

  def png(width: 64, height: 48)
    gradient(width, height).pngsave_buffer
  end

  def webp(width: 64, height: 48)
    gradient(width, height).webpsave_buffer
  end

  def truncated_jpeg
    full = gradient(800, 600).jpegsave_buffer(Q: 95)
    full.byteslice(0, full.bytesize / 2)
  end

  def text_named_jpg
    "this is not an image, just text\n" * 20
  end

  # Solid colour compresses to a few KB on disk, but the header declares 41 MP.
  def jpeg_41_megapixels
    solid(8200, 5000).jpegsave_buffer(Q: 50)
  end
end

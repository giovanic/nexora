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

  # A HEIC container built at test time. The local libheif has no HEVC encoder, so the
  # pixels are AV1 (libheif decodes by item type) and the major brand is rewritten to
  # "heic", which is what the magic-byte detection and the loader see on an iPhone file.
  # Where a HEVC encoder exists it is used and the bytes are untouched.
  def heic(width: 64, height: 48, brand: "heic")
    image = gradient(width, height)
    bytes = begin
      image.heifsave_buffer(Q: 60, compression: :hevc)
    rescue Vips::Error
      image.heifsave_buffer(Q: 60, compression: :av1).tap { |b| b[8, 4] = brand }
    end
    bytes.b.tap { |b| b[8, 4] = brand }
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

  # CMYK JPEG carrying a CMYK ICC profile (the one built into libvips).
  def cmyk_jpeg_with_icc
    gradient(80, 60).icc_export(output_profile: "cmyk").jpegsave_buffer
  end

  # Two frames of different colour, so the file has n-pages = 2.
  def animated_webp(width: 40, height: 30)
    frames = [ [ 255, 0, 0 ], [ 0, 0, 255 ] ].map { |color| solid(width, height, color) }
    Vips::Image.arrayjoin(frames, across: 1).mutate do |m|
      m.set_type! GObject::GINT_TYPE, "page-height", height
    end.webpsave_buffer
  end
end

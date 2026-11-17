require "rails_helper"
require "support/image_fixtures"

RSpec.describe FoodAi::NormalizePhoto do
  def call(bytes, declared_type = "image/jpeg")
    described_class.call(bytes: bytes, declared_type: declared_type)
  end

  def error_code_for(bytes, declared_type = "image/jpeg")
    call(bytes, declared_type)
    nil
  rescue FoodAi::InvalidPhotoError => e
    e.code
  end

  def vips(bytes)
    Vips::Image.new_from_buffer(bytes, "")
  end

  describe "the fixture" do
    it "really carries GPS and Orientation=6" do
      image = vips(ImageFixtures.jpeg_with_gps)

      expect(image.get_fields).to include("exif-ifd3-GPSLatitude", "exif-ifd3-GPSLongitude")
      expect(image.get("orientation")).to eq(6)
    end
  end

  it "removes GPS and every EXIF field" do
    result = call(ImageFixtures.jpeg_with_gps)
    fields = vips(result.bytes).get_fields

    expect(fields).not_to include("exif-data")
    expect(fields.grep(/\Aexif-ifd/)).to be_empty
    expect(fields).not_to include("xmp-data", "iptc-data", "icc-profile-data")
    expect(result.bytes.b).not_to include("GPS".b)
  end

  it "applies the orientation before removing it" do
    result = call(ImageFixtures.jpeg_with_gps(width: 200, height: 100))

    expect([ result.width, result.height ]).to eq([ 100, 200 ])
    expect(vips(result.bytes).width).to eq(100)
    reread = vips(result.bytes)
    expect(reread.get_typeof("orientation") == 0 || reread.get("orientation") == 1).to be(true)
  end

  it "limits the long edge to 1568 px and keeps the aspect ratio" do
    result = call(ImageFixtures.jpeg(width: 3200, height: 1600))

    expect(result.width).to eq(1568)
    expect(result.height).to eq(784)
    expect([ vips(result.bytes).width, vips(result.bytes).height ]).to eq([ 1568, 784 ])
  end

  it "does not enlarge a small image" do
    result = call(ImageFixtures.jpeg(width: 300, height: 200))

    expect([ result.width, result.height ]).to eq([ 300, 200 ])
  end

  it "returns a JPEG whatever the input" do
    expect(call(ImageFixtures.png, "image/png").content_type).to eq("image/jpeg")
    expect(call(ImageFixtures.webp, "image/webp").content_type).to eq("image/jpeg")
    expect(Marcel::MimeType.for(StringIO.new(call(ImageFixtures.png, "image/png").bytes))).to eq("image/jpeg")
  end

  describe "HEIC and HEIF (owner decision 2026-11-14)" do
    before { skip "libvips here has no heifsave, cannot build the HEIC fixture" unless Vips.get_suffixes.include?(".heic") && Vips::Image.black(8, 8).respond_to?(:heifsave_buffer) }

    it "converts HEIC to a JPEG with no metadata" do
      result = call(ImageFixtures.heic(width: 200, height: 100), "image/heic")

      expect(result.content_type).to eq("image/jpeg")
      expect(Marcel::MimeType.for(StringIO.new(result.bytes))).to eq("image/jpeg")
      expect([ result.width, result.height ]).to eq([ 200, 100 ])
      fields = vips(result.bytes).get_fields
      expect(fields).not_to include("exif-data", "xmp-data", "icc-profile-data")
    end

    it "limits the long edge of a HEIC to 1568 px" do
      result = call(ImageFixtures.heic(width: 3200, height: 1600), "image/heic")

      expect([ result.width, result.height ]).to eq([ 1568, 784 ])
    end

    it "accepts HEIF (mif1 brand) declared as image/heif" do
      result = call(ImageFixtures.heic(brand: "mif1"), "image/heif")

      expect(result.content_type).to eq("image/jpeg")
    end

    it "accepts a HEIF file declared as image/heic and the other way round" do
      expect(call(ImageFixtures.heic(brand: "mif1"), "image/heic").content_type).to eq("image/jpeg")
      expect(call(ImageFixtures.heic, "image/heif").content_type).to eq("image/jpeg")
    end

    it "refuses 41 megapixels of HEIF without decoding the pixels" do
      bytes = ImageFixtures.heic_41_megapixels
      expect(bytes.bytesize).to be < 10 * 1024 * 1024

      operations = []
      allow_any_instance_of(Vips::Image).to receive(:method_missing).and_wrap_original do |original, name, *args, **kwargs, &block|
        operations << name
        original.call(name, *args, **kwargs, &block)
      end
      loads = []
      allow(Vips::Image).to receive(:new_from_buffer).and_wrap_original do |original, *args, **kwargs|
        loads << kwargs[:access]
        original.call(*args, **kwargs)
      end

      expect(error_code_for(bytes, "image/heic")).to eq("too_many_pixels")
      expect(loads).to eq([ :sequential ])
      expect(operations).to be_empty
    end

    it "returns a rotated HEIC upright, with no metadata left" do
      bytes = ImageFixtures.heic_rotated
      source = vips(bytes)
      expect(source.get_fields).to include("exif-data")
      expect([ source.width, source.height ]).to eq([ 100, 200 ])

      result = call(bytes, "image/heic")
      output = vips(result.bytes)

      expect([ result.width, result.height ]).to eq([ 100, 200 ])
      expect([ output.width, output.height ]).to eq([ 100, 200 ])
      expect(output.get_fields).not_to include("exif-data", "xmp-data", "icc-profile-data")
      expect(output.get_fields.grep(/\Aexif-ifd/)).to be_empty
    end

    it "refuses a HEIC declared as image/jpeg" do
      expect(error_code_for(ImageFixtures.heic, "image/jpeg")).to eq("unsupported_media_type")
    end

    it "refuses a truncated HEIC as unreadable_image" do
      bytes = ImageFixtures.heic(width: 400, height: 300)

      expect(error_code_for(bytes.byteslice(0, bytes.bytesize / 2), "image/heic")).to eq("unreadable_image")
    end
  end

  it "refuses a text file named .jpg" do
    expect(error_code_for(ImageFixtures.text_named_jpg)).to eq("unsupported_media_type")
  end

  it "refuses an empty body" do
    expect(error_code_for("")).to eq("unsupported_media_type")
  end

  it "refuses a declared type that differs from the bytes" do
    expect(error_code_for(ImageFixtures.png, "image/jpeg")).to eq("unsupported_media_type")
  end

  it "refuses a real type outside jpeg, png, webp, heic and heif even when declared" do
    gif = "GIF89a\x01\x00\x01\x00\x80\x00\x00\x00\x00\x00\xFF\xFF\xFF!\xF9\x04\x01\x00\x00\x00\x00,\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02D\x01\x00;".b

    expect(error_code_for(gif, "image/gif")).to eq("unsupported_media_type")
  end

  it "refuses more than 10 MB" do
    expect(error_code_for("\xFF\xD8\xFF".b + ("a" * (10 * 1024 * 1024)))).to eq("too_large")
  end

  it "refuses 41 megapixels without decoding the pixels" do
    bytes = ImageFixtures.jpeg_41_megapixels
    expect(bytes.bytesize).to be < 10 * 1024 * 1024

    # ruby-vips resolves every operation through method_missing. Width and height are real
    # methods and the load is a class method, so on the refusal path nothing may reach it.
    operations = []
    allow_any_instance_of(Vips::Image).to receive(:method_missing).and_wrap_original do |original, name, *args, **kwargs, &block|
      operations << name
      original.call(name, *args, **kwargs, &block)
    end
    loads = []
    allow(Vips::Image).to receive(:new_from_buffer).and_wrap_original do |original, *args, **kwargs|
      loads << kwargs[:access]
      original.call(*args, **kwargs)
    end

    expect(error_code_for(bytes)).to eq("too_many_pixels")
    expect(loads).to eq([ :sequential ])
    expect(operations).to be_empty
  end

  it "accepts exactly 40 megapixels" do
    bytes = ImageFixtures.solid(8000, 5000).jpegsave_buffer(Q: 50)

    result = call(bytes)

    expect([ result.width, result.height ]).to eq([ 1568, 980 ])
  end

  it "converts an image with an ICC profile to sRGB and drops the profile" do
    tagged = ImageFixtures.cmyk_jpeg_with_icc
    source = vips(tagged)
    expect(source.get_fields).to include("icc-profile-data")
    expect(source.interpretation).to eq(:cmyk)

    result = call(tagged)
    output = vips(result.bytes)

    expect(output.get_fields).not_to include("icc-profile-data")
    expect(output.interpretation).to eq(:srgb)
    expect(output.bands).to eq(3)
  end

  it "falls back to a plain strip when the colour transform fails" do
    tagged = ImageFixtures.cmyk_jpeg_with_icc
    allow_any_instance_of(Vips::Image).to receive(:method_missing).and_wrap_original do |original, name, *args, **kwargs, &block|
      raise Vips::Error, "bad profile" if name == :icc_transform

      original.call(name, *args, **kwargs, &block)
    end

    result = call(tagged)
    output = vips(result.bytes)

    expect(output.get_fields).not_to include("icc-profile-data")
    expect([ result.width, result.height ]).to eq([ 80, 60 ])
  end

  it "normalizes an animated WebP from its first frame only" do
    animated = ImageFixtures.animated_webp(width: 40, height: 30)
    expect(vips(animated).get("n-pages")).to eq(2)

    result = call(animated, "image/webp")

    expect([ result.width, result.height ]).to eq([ 40, 30 ])
    expect(vips(result.bytes).height).to eq(30)
  end

  it "refuses a truncated JPEG" do
    expect(error_code_for(ImageFixtures.truncated_jpeg)).to eq("unreadable_image")
  end

  it "error messages carry only the code" do
    error = begin
      call(ImageFixtures.truncated_jpeg)
    rescue FoodAi::InvalidPhotoError => e
      e
    end

    expect(error.code).to eq("unreadable_image")
    expect(error.message).to eq("unreadable_image")
    expect(error.cause).to be_nil.or(be_a(Vips::Error))
    expect(error.message).not_to match(/vips|jpeg|\.jpg|bytes/i)
  end

  it "returns a frozen value object" do
    result = call(ImageFixtures.jpeg)

    expect(result).to be_a(FoodAi::NormalizedPhoto)
    expect(result).to be_frozen
  end
end

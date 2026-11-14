#!/usr/bin/env ruby
# Rebuilds the evaluation images from manifest.yml, outside the repository.
#
#   ruby evaluation/fetch.rb          (needs the ruby-vips gem and libvips; no Rails)
#   cd apps/api && bundle exec ruby ../../evaluation/fetch.rb
#
# Images go to $EVALUATION_IMAGES_DIR, or to ~/.cache/nexora-evaluation. Every original and every derivative is
# checked against the sha256 of the manifest: a file that does not match is never kept, and the exit status is 1.
# Derivatives are produced here with libvips and are byte-identical only for the libvips and the font of the
# manifest ("render" key). On another libvips the check fails, on purpose: the dataset must not drift silently.
require "digest"
require "fileutils"
require "net/http"
require "openssl"
require "uri"
require "yaml"
require "zlib"

module Evaluation
  module Fetch
    USER_AGENT = "nexora-evaluation-fetch/1.0 (licensed dataset rebuild)".freeze
    MANIFEST = File.expand_path("manifest.yml", __dir__)
    RETRIES = 5
    MAX_WAIT = 180 # seconds: a longer Retry-After is a failure to report, not a wait
    TAIL_BYTES = 65_536
    EOCD = "PK\x05\x06".b.freeze

    class Error < StandardError; end
    # The bytes are not the ones the manifest names. The message carries the image id only, never content.
    class Mismatch < Error; end

    module_function

    def images_dir(env = ENV)
      value = env["EVALUATION_IMAGES_DIR"].to_s.strip
      value.empty? ? File.join(Dir.home, ".cache", "nexora-evaluation") : value
    end

    def sha256(bytes) = Digest::SHA256.hexdigest(bytes)

    def verify!(entry, bytes)
      raise Mismatch, "sha256 mismatch for #{entry['id']}" unless sha256(bytes) == entry["sha256"]

      bytes
    end

    # ---- transport -------------------------------------------------------------------------------------------

    # GET with redirects and a patient retry on 429/503. range: "bytes=a-b". Returns the body.
    def http_get(url, range: nil, redirects: 5, retries: RETRIES)
      uri = URI(url)
      request = Net::HTTP::Get.new(uri.request_uri, { "User-Agent" => USER_AGENT })
      request["Range"] = range if range
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 20, read_timeout: 120) { |http| http.request(request) }
      case response
      when Net::HTTPSuccess then response.body.b
      when Net::HTTPRedirection
        raise Error, "too many redirects for #{uri.host}" if redirects.zero?

        http_get(URI.join(url, response["location"]).to_s, range:, redirects: redirects - 1, retries:)
      else
        if %w[429 503].include?(response.code) && retries.positive?
          # 10, 20, 40, 80, 160 s, or the server's Retry-After, never more than MAX_WAIT
          sleep([ [ response["retry-after"].to_i, 10 * (2**(RETRIES - retries)) ].max, MAX_WAIT ].min)
          return http_get(url, range:, redirects:, retries: retries - 1)
        end
        raise Error, "HTTP #{response.code} from #{uri.host}"
      end
    end

    # ---- one member of a remote zip, by range requests ---------------------------------------------------------

    def zip_member(archive_url, member, http: method(:http_get))
      tail = http.call(archive_url, range: "bytes=-#{TAIL_BYTES}").b
      at = tail.rindex(EOCD) or raise Error, "not a zip archive"
      _sig, _disk, _cd_disk, _here, entries, cd_size, cd_offset = tail.byteslice(at, 22).unpack("VvvvvVV")
      raise Error, "zip64 archives are not supported" if cd_offset == 0xFFFFFFFF || entries == 0xFFFF

      tail_start = (cd_offset + cd_size) - at # the central directory ends where the end record begins
      directory = if cd_offset >= tail_start
                    tail.byteslice(cd_offset - tail_start, cd_size)
      else
                    http.call(archive_url, range: "bytes=#{cd_offset}-#{cd_offset + cd_size - 1}").b
      end
      record = find_central_record(directory, entries, member) or raise Error, "member not found in the archive"
      read_member(archive_url, record, http)
    end

    def find_central_record(directory, entries, member)
      position = 0
      entries.times do
        sig, _made, _need, _flags, method, _time, _date, crc, csize, usize, nlen, elen, clen, _disk, _int, _ext, offset =
          directory.byteslice(position, 46).unpack("VvvvvvvVVVvvvvvVV")
        raise Error, "broken central directory" unless sig == 0x02014b50

        name = directory.byteslice(position + 46, nlen).force_encoding(Encoding::UTF_8)
        return { method:, crc:, csize:, usize:, offset: } if name == member

        position += 46 + nlen + elen + clen
      end
      nil
    end

    def read_member(archive_url, record, http)
      header = http.call(archive_url, range: "bytes=#{record[:offset]}-#{record[:offset] + 29}").b
      sig, _need, _flags, _method, _time, _date, _crc, _cs, _us, nlen, elen = header.unpack("VvvvvvVVVvv")
      raise Error, "broken local header" unless sig == 0x04034b50

      start = record[:offset] + 30 + nlen + elen
      data = http.call(archive_url, range: "bytes=#{start}-#{start + record[:csize] - 1}").b
      data = case record[:method]
      when 0 then data
      when 8 then Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(data)
      else raise Error, "unsupported zip method"
      end
      raise Error, "member does not match the archive checksum" unless data.bytesize == record[:usize] && Zlib.crc32(data) == record[:crc]

      data
    rescue Zlib::Error
      raise Error, "member does not match the archive checksum"
    end

    # ---- derivatives -----------------------------------------------------------------------------------------

    # recipe: { "op" => "darken", "factor" => } | { "op" => "blur", "sigma" => } | { "op" => "overlay_text", "text" => }.
    # Returns PNG bytes, without metadata.
    def derive(recipe, source_bytes)
      require "vips"
      image = rgb(Vips::Image.new_from_buffer(source_bytes, ""))
      result =
        case recipe["op"]
        when "darken" then (image * recipe.fetch("factor").to_f).cast(:uchar)
        when "blur" then image.gaussblur(recipe.fetch("sigma").to_f).cast(:uchar)
        when "overlay_text" then overlay_text(image, recipe.fetch("text"))
        else raise Error, "unknown derive op"
        end
      result.pngsave_buffer(compression: 6, strip: true)
    end

    def rgb(image)
      image = image.colourspace(:srgb)
      image = image.extract_band(0, n: 3) if image.bands > 3
      image
    end

    # Black text on a white band, in the middle of the image, in DejaVu Sans Bold.
    def overlay_text(image, text)
      size = [ image.width / 18, 12 ].max
      mask = Vips::Image.text(text, font: "DejaVu Sans Bold #{size}", width: (image.width * 0.9).to_i, align: :centre, dpi: 72)
      pad = [ size / 2, 6 ].max
      ink = mask.invert # white page, black glyphs
      band = ink.bandjoin([ ink, ink ]).copy(interpretation: :srgb).embed(pad, pad, mask.width + (2 * pad), mask.height + (2 * pad), extend: :white)
      image.insert(band, [ (image.width - band.width) / 2, 0 ].max, [ (image.height - band.height) / 2, 0 ].max)
    end

    # ---- the run ---------------------------------------------------------------------------------------------

    def fetch_original(entry, http)
      fetch = entry.fetch("fetch")
      case fetch["method"]
      when "https" then http.call(fetch.fetch("url", entry["source_url"]))
      when "zip_member" then zip_member(fetch.fetch("archive_url"), fetch.fetch("member"), http:)
      else raise Error, "unknown fetch method for #{entry['id']}"
      end
    end

    def store(dir, file, bytes)
      FileUtils.mkdir_p(dir)
      path = File.join(dir, file)
      temp = "#{path}.part"
      File.binwrite(temp, bytes)
      File.rename(temp, path)
    end

    # manifest: the parsed manifest.yml. Returns { verified:, downloaded:, failures: [{ id:, reason: }] }.
    # reason is a closed text: mismatch, unavailable, or no_source. Never the content.
    def run(manifest:, dir:, http: method(:http_get))
      images = manifest.fetch("images")
      result = { verified: 0, downloaded: 0, failures: [] }
      files = images.to_h { [ _1["id"], _1["file"] ] }
      ready = {}

      (images.reject { _1["derive"] } + images.select { _1["derive"] }).each do |entry|
        path = File.join(dir, entry["file"])
        if File.file?(path) && sha256(File.binread(path)) == entry["sha256"]
          ready[entry["id"]] = true
          result[:verified] += 1
          next
        end

        begin
          bytes = obtain(entry, files, dir, ready, http)
          verify!(entry, bytes)
          store(dir, entry["file"], bytes)
          ready[entry["id"]] = true
          result[:verified] += 1
          result[:downloaded] += 1
        rescue Mismatch
          result[:failures] << { id: entry["id"], reason: "mismatch" }
        rescue Error, SystemCallError, SocketError, Timeout::Error, OpenSSL::SSL::SSLError, Net::ProtocolError, IOError => error
          result[:failures] << { id: entry["id"], reason: error.is_a?(Error) && error.message == "no source" ? "no_source" : "unavailable" }
        end
      end
      result
    end

    def obtain(entry, files, dir, ready, http)
      return fetch_original(entry, http) unless entry["derive"]

      source = entry["derived_from"]
      raise Error, "no source" unless ready[source]

      derive(entry["derive"], File.binread(File.join(dir, files.fetch(source))))
    end

    def main(manifest_path: MANIFEST, dir: images_dir, http: method(:http_get), out: $stdout)
      manifest = YAML.safe_load_file(manifest_path)
      result = run(manifest:, dir:, http:)
      total = manifest["images"].size
      result[:failures].each { |failure| out.puts "FAIL #{failure[:id]}: #{failure[:reason]}" }
      if result[:failures].any? { |failure| failure[:reason] == "mismatch" && manifest["images"].any? { _1["id"] == failure[:id] && _1["derive"] } }
        out.puts "derived images depend on libvips #{manifest.dig('render', 'libvips')} and the font #{manifest.dig('render', 'font')} (see README.md)"
      end
      out.puts "evaluation images: #{result[:verified]}/#{total} sha256 verified (#{result[:downloaded]} fetched), " \
               "#{result[:failures].size} failed, folder #{dir}"
      result[:failures].empty? && result[:verified] == total ? 0 : 1
    end
  end
end

exit(Evaluation::Fetch.main) if $PROGRAM_NAME == __FILE__

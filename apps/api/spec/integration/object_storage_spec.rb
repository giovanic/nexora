require "rails_helper"
require "support/object_storage"
require "net/http"
require "securerandom"

# Proof of ADR 0019 against the real local SeaweedFS (docker compose up -d --wait).
RSpec.describe "private object storage", :object_storage do
  let(:storage) { FoodAi.storage }
  let(:key) { "food-photos/#{SecureRandom.uuid}" }
  let(:bytes) { "\xFF\xD8\xFF\xE0jpeg-bytes".b }

  after { storage.delete(key: key) }

  def put(upload, body:, headers: upload.headers)
    uri = URI(upload.url)
    request = Net::HTTP::Put.new(uri)
    headers.each { |name, value| request[name] = value }
    request.body = body
    Net::HTTP.start(uri.host, uri.port) { |http| http.request(request) }
  end

  it "presigned PUT with the signed length and type stores the object" do
    upload = storage.presigned_put(key: key, content_type: "image/jpeg", byte_size: bytes.bytesize)

    expect(put(upload, body: bytes).code).to eq("200")
    expect(storage.head(key: key)).to eq(FoodAi::Adapters::ObjectStorage::ObjectInfo.new(byte_size: bytes.bytesize, content_type: "image/jpeg"))
    expect(storage.read(key: key)).to eq(bytes)
  end

  it "PUT with a Content-Length other than the signed one is refused" do
    upload = storage.presigned_put(key: key, content_type: "image/jpeg", byte_size: bytes.bytesize)

    response = put(upload, body: bytes + "extra", headers: upload.headers.except("Content-Length"))

    expect(response.code.to_i).to be >= 400
    expect(storage.head(key: key)).to be_nil
  end

  it "PUT with another Content-Type is refused" do
    upload = storage.presigned_put(key: key, content_type: "image/jpeg", byte_size: bytes.bytesize)

    response = put(upload, body: bytes, headers: upload.headers.merge("Content-Type" => "text/html"))

    expect(response.code.to_i).to be >= 400
    expect(storage.head(key: key)).to be_nil
  end

  it "GET without a signature is refused" do
    storage.write(key: key, bytes: bytes, content_type: "image/jpeg")
    signed = URI(storage.presigned_get(key: key))
    unsigned = URI("#{signed.scheme}://#{signed.host}:#{signed.port}#{signed.path}")

    expect(Net::HTTP.get_response(unsigned).code.to_i).to be >= 400
    expect(Net::HTTP.get_response(signed).body.b).to eq(bytes)
  end

  it "presigned URL is refused after it expires" do
    upload = storage.presigned_put(key: key, content_type: "image/jpeg", byte_size: bytes.bytesize, expires_in: 1)
    sleep 2

    expect(put(upload, body: bytes).code.to_i).to be >= 400
    expect(storage.head(key: key)).to be_nil
  end

  it "expires_in above 900 raises ArgumentError" do
    expect { storage.presigned_put(key: key, content_type: "image/jpeg", byte_size: 1, expires_in: 901) }.to raise_error(ArgumentError)
    expect { storage.presigned_get(key: key, expires_in: 901) }.to raise_error(ArgumentError)
  end

  it "delete is idempotent and read of a missing key is nil" do
    expect { 2.times { storage.delete(key: key) } }.not_to raise_error
    expect(storage.read(key: key)).to be_nil
  end
end

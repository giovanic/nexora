require "rails_helper"

RSpec.describe FoodAi::Adapters::MemoryStorage do
  subject(:storage) { described_class.new }

  let(:key) { "food-photos/abc" }

  it "is the storage FoodAi.storage returns in the test environment" do
    expect(FoodAi.storage).to be_a(described_class)
  end

  describe "isolation between examples", order: :defined do
    it "leaves an object in FoodAi.storage" do
      FoodAi.storage.write(key: "leak", bytes: "x", content_type: "image/jpeg")

      expect(FoodAi.storage.head(key: "leak")).not_to be_nil
    end

    it "starts the next example with an empty FoodAi.storage" do
      expect(FoodAi.storage.head(key: "leak")).to be_nil
    end
  end

  it "writes, heads, reads and deletes" do
    storage.write(key: key, bytes: "abc", content_type: "image/jpeg")

    expect(storage.head(key: key)).to eq(FoodAi::Adapters::ObjectStorage::ObjectInfo.new(byte_size: 3, content_type: "image/jpeg"))
    expect(storage.read(key: key)).to eq("abc")

    storage.delete(key: key)
    expect(storage.head(key: key)).to be_nil
    expect(storage.read(key: key)).to be_nil
  end

  it "delete is idempotent" do
    expect { 2.times { storage.delete(key: key) } }.not_to raise_error
  end

  it "presigned_put returns the url, the signed headers and the expiry" do
    upload = storage.presigned_put(key: key, content_type: "image/jpeg", byte_size: 3)

    expect(upload).to be_a(FoodAi::Adapters::ObjectStorage::PresignedUpload)
    expect(upload.headers).to include("Content-Type" => "image/jpeg", "Content-Length" => "3")
    expect(upload.expires_at).to be_within(5).of(900.seconds.from_now)
  end

  it "presigned_get returns a string" do
    expect(storage.presigned_get(key: key)).to be_a(String)
  end

  it "refuses an expiry above 900 seconds" do
    expect { storage.presigned_put(key: key, content_type: "image/jpeg", byte_size: 1, expires_in: 901) }.to raise_error(ArgumentError)
    expect { storage.presigned_get(key: key, expires_in: 901) }.to raise_error(ArgumentError)
  end
end

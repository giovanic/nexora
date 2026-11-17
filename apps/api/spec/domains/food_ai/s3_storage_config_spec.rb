require "rails_helper"

RSpec.describe FoodAi::Adapters::S3Storage, ".from_env" do
  def client_of(storage) = storage.instance_variable_get(:@client)

  it "uses the local docker-compose defaults outside production" do
    storage = described_class.from_env(env: {})

    expect(client_of(storage).config.endpoint.to_s).to eq("http://127.0.0.1:8334")
    expect(client_of(storage).config.region).to eq("us-east-1")
    expect(client_of(storage).config.credentials.access_key_id).to eq("app_dev_access_key")
  end

  it "treats an empty STORAGE_ENDPOINT as absent" do
    storage = described_class.from_env(env: { "STORAGE_ENDPOINT" => "" })

    expect(client_of(storage).config.endpoint.to_s).to eq("http://127.0.0.1:8334")
  end

  context "in production" do
    before { allow(Rails.env).to receive(:production?).and_return(true) }

    let(:env) do
      { "STORAGE_BUCKET" => "b", "STORAGE_REGION" => "sa-east-1", "STORAGE_ENDPOINT" => "",
        "STORAGE_ACCESS_KEY_ID" => "prod-key", "STORAGE_SECRET_ACCESS_KEY" => "prod-secret" }
    end

    it "does not fall back to the local endpoint when STORAGE_ENDPOINT is empty" do
      storage = described_class.from_env(env: env)

      expect(client_of(storage).config.endpoint.to_s).to include("sa-east-1")
      expect(client_of(storage).config.endpoint.to_s).not_to include("127.0.0.1")
    end

    it "does not fall back to the development credentials or bucket" do
      allow(Aws::S3::Client).to receive(:new).and_return(instance_double(Aws::S3::Client, config: nil))
      allow(Aws::S3::Presigner).to receive(:new)

      storage = described_class.from_env(env: env.merge("STORAGE_ACCESS_KEY_ID" => "", "STORAGE_BUCKET" => ""))

      expect(Aws::S3::Client).to have_received(:new).with(hash_including(access_key_id: nil))
      expect(storage.instance_variable_get(:@bucket)).to be_nil
    end
  end
end

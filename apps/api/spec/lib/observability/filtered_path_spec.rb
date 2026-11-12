require "rails_helper"
require "observability/filtered_path"

RSpec.describe Observability::FilteredPath do
  def request_for(path, path_parameters)
    ActionDispatch::Request.new(Rack::MockRequest.env_for(path)).tap do |request|
      request.path_parameters = path_parameters
    end
  end

  it "hides a path segment whose parameter name is filtered" do
    request = request_for("/api/v1/password_resets/secret-abc", { controller: "api/v1/password_resets", action: "update", token: "secret-abc" })

    expect(described_class.call(request, "/api/v1/password_resets/secret-abc")).to eq("/api/v1/password_resets/[FILTERED]")
  end

  it "also hides the escaped form of the value" do
    request = request_for("/api/v1/password_resets/a%20b", { controller: "api/v1/password_resets", action: "update", token: "a b" })

    expect(described_class.call(request, "/api/v1/password_resets/a%20b")).to eq("/api/v1/password_resets/[FILTERED]")
  end

  it "keeps segments whose names are not filtered, such as an id" do
    id = SecureRandom.uuid
    request = request_for("/api/v1/sessions/#{id}", { controller: "api/v1/sessions", action: "destroy", id: })

    expect(described_class.call(request, "/api/v1/sessions/#{id}")).to eq("/api/v1/sessions/#{id}")
  end

  it "keeps the path of a request that matched no route" do
    request = request_for("/nowhere", {})

    expect(described_class.call(request, "/nowhere")).to eq("/nowhere")
    expect(described_class.call(nil, "/nowhere")).to eq("/nowhere")
  end
end

require "rails_helper"
require "support/contract"

RSpec.describe "central error format" do
  shared_examples "a central error" do |status, code|
    it "responds #{status} with code #{code}" do
      perform

      expect(response).to have_http_status(status)
      expect(response.media_type).to eq("application/json")
      expect(response.parsed_body.dig("error", "code")).to eq(code)
      expect(response.parsed_body.dig("error", "message")).to be_present
      expect(response.parsed_body.dig("error", "request_id")).to eq(response.headers["X-Request-Id"])
    end
  end

  context "when the route does not exist" do
    let(:perform) { get "/nao/existe" }

    it_behaves_like "a central error", 404, "not_found"
  end

  it "responds 400 in the central format when the JSON body is malformed" do
    stub_const("ProbeController", Class.new(ActionController::API) do
      def create
        render json: params.to_unsafe_h
      end
    end)

    with_routing do |routes|
      routes.draw { post "/probe", to: "probe#create" }

      post "/probe", params: '{"a":', headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:bad_request)
      expect(response.media_type).to eq("application/json")
      expect(response.parsed_body.dig("error", "code")).to eq("bad_request")
      expect(response.parsed_body.dig("error", "request_id")).to eq(response.headers["X-Request-Id"])
    end
  end

  context "when an unexpected exception is raised" do
    before do
      allow_any_instance_of(HealthController).to receive(:live).and_raise(RuntimeError, "internal-secret-detail")
    end

    let(:perform) { get "/health/live" }

    it_behaves_like "a central error", 500, "internal_error"

    it "matches the error format in the contract" do
      perform

      expect_response_to_match_contract
    end

    it "does not expose the exception" do
      perform

      expect(response.body).not_to include("internal-secret-detail")
      expect(response.body).not_to include("RuntimeError")
    end
  end

  {
    ActionController::UnknownFormat => [ 406, "not_acceptable" ],
    ActionController::BadRequest => [ 400, "bad_request" ],
    ActionController::MethodNotAllowed => [ 405, "method_not_allowed" ],
    ActiveRecord::RecordNotFound => [ 404, "not_found" ]
  }.each do |exception, (status, code)|
    it "keeps #{exception} as #{status} #{code}" do
      arguments = exception == ActionController::MethodNotAllowed ? [ "GET" ] : []
      allow_any_instance_of(HealthController).to receive(:live).and_raise(exception.new(*arguments))

      get "/health/live"

      expect(response).to have_http_status(status)
      expect(response.parsed_body.dig("error", "code")).to eq(code)
    end
  end

  it "returns the correlation identifier on an error response" do
    get "/nao/existe", headers: { "X-Correlation-Id" => "corr-error-1" }

    expect(response.headers["x-correlation-id"]).to eq("corr-error-1")
  end

  it "does not let a client request an error page directly" do
    get "/500"

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body.dig("error", "code")).to eq("not_found")
  end
end

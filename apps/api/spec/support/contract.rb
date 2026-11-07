require "openapi_first"

# Validates real responses from request specs against the OpenAPI contract, so a
# response that drifts from the file clients generate their types from fails here.
module Contract
  PATH = Rails.root.join("../../packages/contracts/openapi.yaml").to_s

  def self.definition
    @definition ||= OpenapiFirst.load(PATH)
  end

  def self.paths
    YAML.load_file(PATH).fetch("paths").keys
  end

  def expect_response_to_match_contract
    validated = Contract.definition.validate_response(request, response)

    expect(validated).to be_valid, -> { "response does not match the contract: #{validated.error&.message}" }
  end
end

RSpec.configure { |config| config.include Contract, type: :request }

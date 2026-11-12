require "openapi_first"

# Validates real responses from request specs against the OpenAPI contract, so a
# response that drifts from the file clients generate their types from fails here.
module Contract
  PATH = Rails.root.join("../../packages/contracts/openapi.yaml").to_s

  def self.definition
    @definition ||= OpenapiFirst.load(PATH)
  end

  HTTP_METHODS = %w[get put post delete patch head options trace].freeze

  # Every documented operation as "VERB /path", with OpenAPI parameters such as {id}.
  def self.operations
    YAML.load_file(PATH).fetch("paths").flat_map do |path, item|
      (item.keys & HTTP_METHODS).map { |method| "#{method.upcase} #{path}" }
    end
  end

  # A Rails route in the same form, converting :id into {id}.
  def self.operation(verb, rails_path)
    path = rails_path.delete_suffix("(.:format)").gsub(/:(\w+)/, '{\\1}')
    "#{verb} #{path}"
  end

  def expect_response_to_match_contract
    validated = Contract.definition.validate_response(request, response)

    expect(validated).to be_valid, -> { "response does not match the contract: #{validated.error&.message}" }
  end
end

RSpec.configure { |config| config.include Contract, type: :request }

require "rails_helper"
require "support/contract"

# The product has no calorie goal, ceiling, balance or day total (NFR-SAFETY-003).
# The API contract must not be able to carry one.
#
# Rule: a property name is forbidden when it contains one of FORBIDDEN and either
#   (a) also names calories (calorie, calories, kcal, energy), or
#   (b) sits in an object that also has a calorie property.
# Tokens match whole snake_case segments. Names are compared in snake_case, so `caloriesRemaining` is caught like `calories_remaining`.
# Every property of every object is checked, wherever it is declared: components, request
# and response bodies, nested objects, array items, allOf/oneOf/anyOf. Query and path
# parameter names are checked the same way (siblings = the other parameters of the operation).
RSpec.describe "OpenAPI contract has no calorie goal" do
  FORBIDDEN = %w[remaining goal limit target deficit total_day day_total daily_total total daily balance budget ceiling cap].freeze
  # Whole snake_case segments (optionally plural), so `cap` does not catch `capacity`
  # and `limit` does not catch `unlimited`.
  FORBIDDEN_NAME = /(?:\A|_)(?:#{FORBIDDEN.join('|')})s?(?:_|\z)/
  CALORIE = /calor|kcal|energy/

  def self.snake(name)
    name.to_s.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
  end

  # Yields [path, property_names] for every object schema found under +node+.
  def self.each_object(node, path = [], &block)
    case node
    when Hash
      props = node["properties"]
      yield path, props.keys if props.is_a?(Hash)
      params = node["parameters"]
      if params.is_a?(Array) && params.all?(Hash)
        yield path + [ "parameters" ], params.filter_map { |param| param["name"] }
      elsif node.key?("in") && node["name"].is_a?(String) && !path.last.is_a?(Integer)
        yield path, [ node["name"] ]
      end
      node.each { |key, value| each_object(value, path + [ key ], &block) }
    when Array
      node.each_with_index { |value, index| each_object(value, path + [ index ], &block) }
    end
  end

  def self.violations(document)
    found = []
    each_object(document) do |path, names|
      snaked = names.to_h { |name| [ name, snake(name) ] }
      has_calories = snaked.values.any? { |name| name.match?(CALORIE) }
      snaked.each do |name, snake_name|
        next unless snake_name.match?(FORBIDDEN_NAME)

        found << "#{path.join('/')}: #{name}" if has_calories || snake_name.match?(CALORIE)
      end
    end
    found.uniq
  end

  let(:document) { YAML.load_file(Contract::PATH) }

  it "has no goal, limit, target, remaining, deficit or day-total property tied to calories" do
    expect(self.class.violations(document)).to eq([])
  end

  it "looks at the calorie schemas it is meant to guard" do
    names = []
    self.class.each_object(document) { |_path, props| names.concat(props) }

    expect(names).to include("calories_min", "calories_likely", "calories_max")
  end

  describe "the check itself" do
    def schema(properties)
      { "components" => { "schemas" => { "Planted" => { "type" => "object", "properties" => properties } } } }
    end

    it "catches a calorie name carrying a forbidden token" do
      planted = schema("calories_remaining" => { "type" => "integer" })

      expect(self.class.violations(planted)).to eq([ "components/schemas/Planted: calories_remaining" ])
    end

    it "catches camelCase" do
      expect(self.class.violations(schema("dailyCalorieGoal" => {}))).not_to be_empty
    end

    it "catches a forbidden property next to calorie fields" do
      planted = schema("calories_likely" => {}, "limit" => { "type" => "integer" })

      expect(self.class.violations(planted)).to eq([ "components/schemas/Planted: limit" ])
    end

    it "catches nested objects, arrays and allOf" do
      inner = { "type" => "object", "properties" => { "kcal_target" => {} } }
      list = { "type" => "object", "properties" => { "items" => { "type" => "array", "items" => inner } } }
      planted = { "paths" => { "/x" => { "post" => { "responses" => { "200" => { "content" => {
        "application/json" => { "schema" => { "allOf" => [ list ] } }
      } } } } } } }

      expect(self.class.violations(planted).size).to eq(1)
    end

    %w[total daily balance budget ceiling cap day_total daily_total calories_total total_day].each do |token|
      it "catches '#{token}' next to calorie fields" do
        planted = schema("calories_likely" => {}, token => { "type" => "integer" })

        expect(self.class.violations(planted)).to eq([ "components/schemas/Planted: #{token}" ])
      end
    end

    it "catches a calorie total without any sibling" do
      expect(self.class.violations(schema("total_calories" => {}))).not_to be_empty
    end

    it "does not flag per_page, quota or capacity next to calorie fields" do
      planted = schema("calories_likely" => {}, "per_page" => {}, "quota" => {}, "capacity" => {})

      expect(self.class.violations(planted)).to eq([])
    end

    it "walks query parameters" do
      planted = { "paths" => { "/x" => { "get" => { "parameters" => [
        { "name" => "calories_goal", "in" => "query" }
      ] } } } }

      expect(self.class.violations(planted).size).to eq(1)
    end

    it "walks a limit parameter next to a calorie parameter" do
      planted = { "paths" => { "/x" => { "get" => { "parameters" => [
        { "name" => "calories_min", "in" => "query" }, { "name" => "limit", "in" => "query" }
      ] } } } }

      expect(self.class.violations(planted).size).to eq(1)
    end

    it "does not flag a limit parameter with no calorie relation" do
      planted = { "paths" => { "/x" => { "get" => { "parameters" => [ { "name" => "limit", "in" => "query" } ] } } } }

      expect(self.class.violations(planted)).to eq([])
    end

    it "walks reusable parameters under components" do
      planted = { "components" => { "parameters" => { "G" => { "name" => "kcal_target", "in" => "query" } } } }

      expect(self.class.violations(planted).size).to eq(1)
    end

    it "does not flag a limit that has nothing to do with calories" do
      expect(self.class.violations(schema("limit" => {}, "name" => {}))).to eq([])
    end
  end
end

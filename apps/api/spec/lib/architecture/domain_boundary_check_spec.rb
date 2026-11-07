require "rails_helper"
require "architecture/domain_boundary_check"
require "tmpdir"

RSpec.describe Architecture::DomainBoundaryCheck do
  let(:rules) do
    {
      "nutrition" => [ "food_catalog" ],
      "food_catalog" => [],
      "goals" => [],
      "gamification" => []
    }
  end

  around do |example|
    Dir.mktmpdir do |dir|
      @root = dir
      example.run
    end
  end

  def write(path, source)
    full = File.join(@root, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, source)
  end

  def violations
    described_class.new(root: @root, rules:).violations
  end

  it "accepts a call to the public API of an allowed context" do
    write("nutrition/a.rb", "module Nutrition; class A; def x = FoodCatalog::Api.search; end; end")

    expect(violations).to eq([])
  end

  it "rejects a reference to another context's internals" do
    write("nutrition/a.rb", "module Nutrition\n  class A\n    def x = FoodCatalog::Item\n  end\nend\n")

    expect(violations.size).to eq(1)
    expect(violations.first).to have_attributes(
      from: "nutrition", to: "food_catalog", constant: "FoodCatalog::Item", reason: :private_constant, line: 3
    )
    expect(violations.first.file).to end_with("nutrition/a.rb")
  end

  it "rejects an absolute reference to another context's internals" do
    write("nutrition/a.rb", "module Nutrition; class A; def x = ::FoodCatalog::Item; end; end")

    expect(violations.map(&:reason)).to eq([ :private_constant ])
  end

  it "rejects a reference deeper than the public API" do
    write("nutrition/a.rb", "module Nutrition; class A; def x = FoodCatalog::Api::Result; end; end")

    expect(violations.map(&:reason)).to eq([ :private_constant ])
  end

  it "rejects a reference to the bare namespace of another context" do
    write("nutrition/a.rb", "module Nutrition; class A; def x = FoodCatalog; end; end")

    expect(violations.map(&:reason)).to eq([ :private_constant ])
  end

  it "rejects a dependency that is not allowed, even through the public API" do
    write("goals/a.rb", "module Goals; class A; def x = Gamification::Api; end; end")

    expect(violations.first).to have_attributes(from: "goals", to: "gamification", reason: :forbidden_dependency)
  end

  it "rejects inheriting from another context's class" do
    write("nutrition/a.rb", "module Nutrition; class A < FoodCatalog::Item; end; end")

    expect(violations.map(&:reason)).to eq([ :private_constant ])
  end

  it "rejects a string that names another context's class, as in an association" do
    write("nutrition/a.rb", 'module Nutrition; class A; has_many :items, class_name: "FoodCatalog::Item"; end; end')

    expect(violations.map(&:constant)).to eq([ "FoodCatalog::Item" ])
    expect(violations.map(&:reason)).to eq([ :private_constant ])
  end

  it "accepts a plain sentence or a single word in a string" do
    write("nutrition/a.rb", 'module Nutrition; class A; def x = ["Goals", "FoodCatalog is great"]; end; end')

    expect(violations).to eq([])
  end

  it "accepts the context's own constants and constants outside the domains" do
    write("nutrition/a.rb", "module Nutrition; class A < ActiveRecord::Base; def x = [Nutrition::B, B, Rails.env]; end; end")

    expect(violations).to eq([])
  end

  it "accepts shared code from any context" do
    write("goals/a.rb", "module Goals; class A; def x = Shared::Events; end; end")

    expect(violations).to eq([])
  end

  it "does not let shared code reference a context" do
    write("shared/a.rb", "module Shared; class A; def x = Goals::Api; end; end")

    expect(violations.first).to have_attributes(from: "shared", to: "goals", reason: :forbidden_dependency)
  end

  it "does not fail on a constant reached through a runtime value" do
    write("nutrition/a.rb", "module Nutrition; class A; def x(klass) = klass::Item; end; end")

    expect(violations).to eq([])
  end

  it "fails naming the file when a file cannot be parsed" do
    write("nutrition/broken.rb", "module Nutrition; class")

    expect { violations }.to raise_error(described_class::UnparseableFile, /broken\.rb/)
  end

  it "fails when a directory has no rules" do
    write("mystery/a.rb", "module Mystery; end")

    expect { violations }.to raise_error(described_class::UnknownContext, /mystery/)
  end

  describe ".cycles" do
    it "finds a cycle" do
      expect(described_class.cycles("a" => [ "b" ], "b" => [ "a" ])).not_to be_empty
    end

    it "finds none in an acyclic graph" do
      expect(described_class.cycles("a" => [ "b" ], "b" => [])).to eq([])
    end
  end
end

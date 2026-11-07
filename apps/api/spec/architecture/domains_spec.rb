require "rails_helper"
require "architecture/domain_boundary_check"

RSpec.describe "domain boundaries" do
  let(:root) { Rails.root.join("app/domains") }
  let(:rules) { YAML.load_file(Rails.root.join("config/domain_boundaries.yml")) }

  it "has no violation in the real domains" do
    violations = Architecture::DomainBoundaryCheck.new(root:, rules:).violations

    expect(violations).to eq([]), violations.map { |v| "#{v.file}:#{v.line} #{v.constant} (#{v.reason})" }.join("\n")
  end

  it "defines rules for exactly the existing contexts" do
    contexts = root.children.select(&:directory?).map { |path| path.basename.to_s } - [ "shared" ]

    expect(rules.keys).to match_array(contexts)
  end

  it "only allows known contexts" do
    expect(rules.values.flatten.uniq - rules.keys).to eq([])
  end

  it "has no cycle in the allowed dependencies" do
    expect(Architecture::DomainBoundaryCheck.cycles(rules)).to eq([])
  end

  it "keeps every context away from gamification, notifications and analytics" do
    expect(rules.values.flatten).not_to include("gamification", "notifications", "progress_analytics")
  end
end

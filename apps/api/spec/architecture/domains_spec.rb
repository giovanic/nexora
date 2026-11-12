require "rails_helper"
require "architecture/domain_boundary_check"

RSpec.describe "domain boundaries" do
  let(:root) { Rails.root.join("app/domains") }
  let(:rules) { YAML.load_file(Rails.root.join("config/domain_boundaries.yml")) }

  let(:outside_roots) { Architecture::DomainBoundaryCheck.application_roots(Rails.root) }

  # A bare constant such as FoodEntry cannot be traced to a context, so business
  # code placed here would escape the check. New files must be added deliberately.
  let(:infrastructure_files) do
    %w[
      app/jobs/smoke_error_job.rb
      app/jobs/smoke_job.rb
      app/models/application_record.rb
      app/services/health/readiness_check.rb
    ]
  end

  it "has no violation in the domains or in the code around them" do
    violations = Architecture::DomainBoundaryCheck.new(root:, rules:, outside_roots:).violations

    expect(violations).to eq([]), violations.map { |v| "#{v.file}:#{v.line} #{v.constant} (#{v.reason})" }.join("\n")
  end

  it "keeps business code out of app/jobs, app/models and app/services" do
    found = Dir.glob(%w[app/jobs app/models app/services].map { |path| Rails.root.join(path, "**/*.rb").to_s })
      .map { |file| Pathname(file).relative_path_from(Rails.root).to_s }

    expect(found).to match_array(infrastructure_files)
  end

  it "analyzes every folder of app/ outside app/domains, and lib/, including new ones" do
    Dir.mktmpdir do |dir|
      %w[app/controllers app/serializers app/domains lib].each { |path| FileUtils.mkdir_p(File.join(dir, path)) }

      roots = Architecture::DomainBoundaryCheck.application_roots(Pathname(dir)).map { |path| path.relative_path_from(Pathname(dir)).to_s }

      expect(roots).to contain_exactly("app/controllers", "app/serializers", "lib")
    end
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

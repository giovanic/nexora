require "rails_helper"
require "open3"
require "tmpdir"

RSpec.describe "domain layout" do
  let(:autoloader) { Rails.autoloaders.main }

  %w[models services jobs].each do |folder|
    it "does not add #{folder} to the constant name" do
      expect(autoloader.dirs(ignored: true)).to include(Rails.root.join("app/domains").to_s)

      directory = Rails.root.join("app/domains/goals/#{folder}")
      FileUtils.mkdir_p(directory)
      file = directory.join("planted_layout.rb")
      File.write(file, "module Goals\n  class PlantedLayout\n  end\nend\n")

      output, status = Bundler.with_original_env do
        Open3.capture2e({ "RAILS_ENV" => "test" }, "bundle", "exec", "rails", "zeitwerk:check", chdir: Rails.root.to_s)
      end

      expect(status).to be_success, output
    ensure
      FileUtils.rm_f(file)
      FileUtils.rmdir(directory) if directory
    end
  end
end

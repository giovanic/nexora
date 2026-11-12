require "rails_helper"
require "erb"

RSpec.describe "database pool and Sidekiq concurrency" do
  def render(file, env)
    previous = env.keys.to_h { |key| [ key, ENV[key] ] }
    env.each { |key, value| ENV[key] = value }
    YAML.safe_load(ERB.new(File.read(Rails.root.join(file))).result, aliases: true)
  ensure
    previous.each { |key, value| ENV[key] = value }
  end

  it "gives the worker at least one connection per Sidekiq thread" do
    env = { "RAILS_MAX_THREADS" => "3", "SIDEKIQ_CONCURRENCY" => "8" }

    concurrency = render("config/sidekiq.yml", env).fetch("concurrency").to_i
    pool = render("config/database.yml", env).dig("production", "max_connections").to_i

    expect(concurrency).to eq(8)
    expect(pool).to be >= concurrency
  end
end

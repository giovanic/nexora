require "rails_helper"
require "rake"

RSpec.describe "food_ai:smoke" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("food_ai:smoke")
  end

  around do |example|
    keys = %w[PROVIDER MODEL IMAGE ANTHROPIC_API_KEY GEMINI_API_KEY OPENAI_API_KEY GROQ_API_KEY]
    saved = ENV.to_h.slice(*keys)
    keys.each { |k| ENV.delete(k) }
    example.run
  ensure
    keys.each { |k| ENV.delete(k) }
    saved.each { |k, v| ENV[k] = v }
  end

  def run_task
    Rake::Task["food_ai:smoke"].reenable
    Rake::Task["food_ai:smoke"].invoke
  end

  it "refuses to run without the provider key, and never opens a connection" do
    ENV["PROVIDER"] = "openai"
    ENV["IMAGE"] = Rails.root.join("Gemfile").to_s
    expect(Net::HTTP).not_to receive(:new)

    expect { run_task }.to raise_error(SystemExit).and output(/cannot start \(unauthorized\)/).to_stderr
  end

  it "offers Groq with its vision model by default, and asks for GROQ_API_KEY without connecting" do
    ENV["PROVIDER"] = "groq"
    ENV["IMAGE"] = Rails.root.join("Gemfile").to_s
    expect(Net::HTTP).not_to receive(:new)
    expect(FoodAi).to receive(:adapter_for).with(provider: "groq", model: "qwen/qwen3.8-27b").and_call_original

    expect { run_task }.to raise_error(SystemExit).and output(/cannot start \(unauthorized\)/).to_stderr
  end

  it "refuses an unknown provider and a missing image" do
    ENV["PROVIDER"] = "nope"
    expect { run_task }.to raise_error(SystemExit).and output(/PROVIDER must be/).to_stderr

    ENV["PROVIDER"] = "gemini"
    ENV["IMAGE"] = "/nonexistent.jpg"
    expect { run_task }.to raise_error(SystemExit).and output(/IMAGE must be/).to_stderr
  end
end

# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "minitest/test_task"

Rake::TestTask.new do |t|
  t.libs = %w[lib test]
  t.pattern = "test/**/*_test.rb"
  t.warning = false
end

Minitest::TestTask.create(:conformance) do |t|
  t.libs = %w[conformance lib test .]
  t.test_globs = %w[conformance/conformance_test.rb]
end

begin
  require "rubocop/rake_task"
  desc "Run rubocop"
  RuboCop::RakeTask.new
rescue LoadError # rubocop:disable Lint/SuppressedException
end

namespace :coverage do
  desc "Aggregates coverage reports"
  task :report do
    return unless ENV.key?("CI")

    require "simplecov"

    SimpleCov.minimum_coverage 85

    SimpleCov.collate Dir["coverage/**/.resultset.json"]
  end
end

task default: %i[test]

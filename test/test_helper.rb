# frozen_string_literal: true

GC.auto_compact = true if GC.respond_to?(:auto_compact=) && RUBY_VERSION >= "3.2.0"

if ENV.key?("CI")
  require "simplecov"
  SimpleCov.command_name "#{RUBY_ENGINE}-#{RUBY_VERSION}"
  coverage_key = ENV.fetch("COVERAGE_KEY", "#{RUBY_ENGINE}-#{RUBY_VERSION}")
  SimpleCov.coverage_dir "coverage/#{coverage_key}"
end

require "minitest"
require "minitest/autorun"

if ENV.key?("PARALLEL")
  require "minitest/hell"
  Minitest::Test.parallelize_me!
end

require "cel"

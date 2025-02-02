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

require "tzinfo" # Required for timestamp timezone conversion tests

require "cel"

module CelAssertions
  def assert_value(ruby_or_cel_value, cel_value)
    if ruby_or_cel_value.is_a?(Cel::Value)
      assert_equal(ruby_or_cel_value, cel_value)
    else
      assert_equal(ruby_or_cel_value, cel_value.to_ruby)
    end
  end

  def assert_nil_value(cel_value)
    assert_nil cel_value.to_ruby
  end
end
Minitest::Test.include(CelAssertions)

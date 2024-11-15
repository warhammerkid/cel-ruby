# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.libs = %w[lib test]
  t.pattern = "test/*_test.rb"
  t.warning = false
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

    SimpleCov.collate Dir["coverage/**/.resultset.json"]
  end
end

task :conformance do
  require_relative "conformance/test_runner"

  ConformanceTestRunner.new(
    File.expand_path("conformance/testdata", __dir__),
    skip_tests: [
      # Crashes attempting to create an empty map with "Hash[nil]"
      "basic/self_eval_zeroish/self_eval_empty_map",
    
      # Bug in string parsing code for empty triple quote strings
      "basic/self_eval_zeroish/self_eval_string_raw_prefix_triple_double",
      "basic/self_eval_zeroish/self_eval_string_raw_prefix_triple_single",
    
      # No single quote escape match in cleanup_escape_sequences
      "basic/self_eval_nonzeroish/self_eval_string_escape",
    
      # Broken octal/hex escape sequence handling
      "basic/self_eval_nonzeroish/self_eval_bytes_invalid_utf8",
    
      # -1 is still an operation but it's trying to convert to a value
      "basic/self_eval_nonzeroish/self_eval_list_singleitem",
    
      # It should be a uint but says it's an int
      "basic/self_eval_nonzeroish/self_eval_uint_hex",
      "basic/self_eval_nonzeroish/self_eval_uint_alias_hex",
    
      # Crashes because Encoding::BPM does not exist?
      "basic/self_eval_nonzeroish/self_eval_unicode_escape_four",
      "comparisons/eq_literal/no_string_normalization",
    
      # No support for \U[0-9a-f]{8} 32-bit encoding
      "basic/self_eval_nonzeroish/self_eval_unicode_escape_eight",
    
      # No support for ascii escape sequences like \a or \v
      "basic/self_eval_nonzeroish/self_eval_ascii_escape_seq",

      # Any exceptions at runtime trigger full expression failure
      # Example: "f_unknown(17) || true" should evaluate to true, not exception
      "basic/variables/unbound_is_runtime_error",
      "basic/functions/unbound_is_runtime_error",

      # No support for cel.bind function
      "bindings_ext/*",

      # No support for cel.block function
      "block_ext/*",

      # No dyn function implementation
      "comparisons/eq_literal/eq_int_uint",
      "comparisons/eq_literal/not_eq_int_uint",
      "comparisons/eq_literal/eq_int_double",
      "comparisons/eq_literal/not_eq_int_double",
      "comparisons/eq_literal/eq_uint_int",
      "comparisons/eq_literal/not_eq_uint_int",
      "comparisons/eq_literal/eq_uint_double",
      "comparisons/eq_literal/not_eq_uint_double",
      "comparisons/eq_literal/not_eq_int_double_nan",
      "comparisons/eq_literal/not_eq_uint_double_nan",
      "comparisons/eq_literal/eq_double_int",
      "comparisons/eq_literal/not_eq_double_int",
      "comparisons/eq_literal/eq_double_uint",
      "comparisons/eq_literal/not_eq_double_uint",
    ]
  ).run
end

task default: %i[test]

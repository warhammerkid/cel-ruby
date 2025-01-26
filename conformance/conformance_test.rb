# frozen_string_literal: true

require "test_helper"

require "cel/extra/encoders"
require "cel/extra/strings"

require "cel/expr/conformance/test/simple_pb"
require "cel/expr/conformance/proto2/test_all_types_pb"
require "cel/expr/conformance/proto3/test_all_types_pb"

require_relative "text_format"

class ConformanceTest < Minitest::Test
  PRIMITIVE_TYPE_MAP = {
    BOOL: :bool,
    INT64: :int,
    UINT64: :uint,
    DOUBLE: :double,
    STRING: :string,
    BYTES: :bytes,
  }.freeze

  # Override runnable_methods to force them to run in the order they are defined
  def self.runnable_methods
    methods_matching(/^test_/)
  end

  # Dyamically define test methods for all conformance tests
  pool = Google::Protobuf::DescriptorPool.generated_pool
  parser = ProtoTextFormat.new(pool.lookup("cel.expr.conformance.test.SimpleTestFile"))
  Dir[File.expand_path("testdata/*.textproto", __dir__)].each do |path| # rubocop:disable Metrics/BlockLength
    # Extension fields are currently not supported for parsing
    next if File.basename(path) == "proto2_ext.textproto"

    simple_test_file = parser.parse(File.read(path))
    simple_test_file.section.each do |section| # rubocop:disable Metrics/BlockLength
      section.test.each do |test|
        # Name method using test name - disambiguate the few duplicates
        method_name = "test_#{simple_test_file.name}_#{section.name}_#{test.name}"
        method_name += "_2" if method_defined?(method_name)

        define_method method_name do
          skip "Any eval errors result not supported" if test.result_matcher == :any_eval_errors
          skip "Unknown result not supported" if test.result_matcher == :unknown
          skip "Any unknowns result not supported" if test.result_matcher == :any_unknowns

          # Set up environment
          declarations = nil
          container = Cel::Container.new(test.container)
          env = Cel::Environment.new(declarations, container)
          extend_env(env)

          # Parse
          ast = Cel::Parser.new.parse(test.expr)

          # Check
          env.check(ast) unless test.disable_check

          # Set up program bindings
          bindings = test.bindings.to_a.to_h do |name, binding|
            [name.to_sym, convert_conformance_value(binding.value)]
          end

          # Run program
          begin
            return_value = env.evaluate(ast, bindings)
            assert(test.result_matcher != :eval_error, "Evaluation should have failed: #{test.eval_error}")

            # Compare with true if no matcher is set
            test.value = Cel::Expr::Value.new(bool_value: true) if test.result_matcher.nil?

            assert_equal convert_conformance_value(test.value), return_value
          rescue StandardError => e
            raise e unless test.result_matcher == :eval_error
          end
        end
      end
    end
  end

  private

  def extend_env(env)
    env.extend_functions(Cel::Extra::Encoders)
    env.extend_functions(Cel::Extra::Strings)
  end

  # Converts Cel::Expr::Value to internal Ruby Cel value
  #
  def convert_conformance_value(value_proto)
    case value_proto.kind
    when :null_value
      Cel::Null.new
    when :bool_value
      Cel::Bool.new(value_proto.bool_value)
    when :int64_value
      Cel::Number.new(:int, value_proto.int64_value)
    when :uint64_value
      Cel::Number.new(:uint, value_proto.uint64_value)
    when :double_value
      Cel::Number.new(:double, value_proto.double_value)
    when :string_value
      Cel::String.new(value_proto.string_value)
    when :bytes_value
      Cel::Bytes.new(value_proto.bytes_value.b)
    when :object_value
      Cel::Message.new(value_proto.object_value)
    when :list_value
      Cel::List.new(value_proto.list_value.values.map { |v| convert_conformance_value(v) })
    when :map_value
      entries = value_proto.map_value.entries.to_a
      Cel::Map.new(entries.to_h { |e| [convert_conformance_value(e.key), convert_conformance_value(e.value)] })
    when :enum_value
      # We don't have an enum type, so just convert it to a number
      Cel::Number.new(:int, value_proto.enum_value.value)
    when :type_value
      case value_proto.type_value
      when "google.protobuf.Timestamp" then Cel::TYPES[:timestamp]
      when "google.protobuf.Duration" then Cel::TYPES[:duration]
      else Cel::TYPES.fetch(value_proto.type_value.to_sym)
      end
    else
      raise "Cannot convert: #{value_proto.inspect}"
    end
  end
end

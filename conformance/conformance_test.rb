# frozen_string_literal: true

require "test_helper"

require "cel/expr/conformance/test/simple_pb"
require "cel/expr/conformance/proto2/test_all_types_pb"
require "cel/expr/conformance/proto3/test_all_types_pb"

class ConformanceTest < Minitest::Test
  PRIMITIVE_TYPE_MAP = {
    BOOL: :bool,
    INT64: :int,
    UINT64: :uint,
    DOUBLE: :double,
    STRING: :string,
    BYTES: :bytes,
  }.freeze

  # Dyamically define test methods for all conformance tests
  Dir[File.expand_path("testdata/*.json", __dir__)].each do |path| # rubocop:disable Metrics/BlockLength
    json = File.binread(path)
    simple_test_file = Cel::Expr::Conformance::Test::SimpleTestFile.decode_json(json)
    simple_test_file.section.each do |section|
      section.test.each do |test|
        # Name method using test name - disambiguate the few duplicates
        method_name = "test_#{simple_test_file.name}_#{section.name}_#{test.name}"
        method_name += "_2" if method_defined?(method_name)

        define_method method_name do
          skip "Any eval errors result not supported" if test.result_matcher == :any_eval_errors
          skip "Unknown result not supported" if test.result_matcher == :unknown
          skip "Any unknowns result not supported" if test.result_matcher == :any_unknowns

          # Set up environment
          declarations = build_declarations(test.type_env)
          container = Cel::Container.new(test.container)
          env = Cel::Environment.new(declarations, container)

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

            expr_value = convert_to_conformance_value(return_value)
            assert_equal test.value, expr_value
          rescue StandardError => e
            raise e unless test.result_matcher == :eval_error
          end
        end
      end
    end
  end

  private

  # Converts Cel::Expr::Decl protos into a declarations hash
  #
  def build_declarations(test_declarations)
    test_declarations.to_h do |decl|
      raise "Cannot declare function: #{decl.inspect}" unless decl.decl_kind == :ident

      [decl.name.to_sym, convert_conformance_type(decl.ident.type)]
    end
  end

  # Converts Cel::Expr::Type proto into Cel::Type
  #
  def convert_conformance_type(type_proto)
    case type_proto.type_kind
    when :primitive
      PRIMITIVE_TYPE_MAP.fetch(type_proto.primitive)
    when :list_type
      Cel::TYPES[:list]
    when :map_type
      Cel::TYPES[:map]
    when :message_type
      :any
    else
      raise "Cannot convert type: #{type_proto.inspect}"
    end
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
      Cel::Bytes.new(value_proto.bytes_value.bytes)
    when :object_value
      Cel::Types::Message.new(value_proto.object_value)
    when :list_value
      Cel::List.new(value_proto.list_value.values.map { |v| convert_conformance_value(v) })
    when :map_value
      entries = value_proto.map_value.entries.to_a
      Cel::Map.new(entries.to_h { |e| [convert_conformance_value(e.key), convert_conformance_value(e.value)] })
    else
      raise "Cannot convert: #{value_proto.inspect}"
    end
  end

  # Converts Cel::Literal to Cel::Expr::Value proto
  #
  def convert_to_conformance_value(value)
    case value
    when Cel::Null
      Cel::Expr::Value.new(null_value: :NULL_VALUE)
    when Cel::Bool
      Cel::Expr::Value.new(bool_value: value.value)
    when Cel::Number
      case value.type
      when Cel::TYPES[:int] then Cel::Expr::Value.new(int64_value: value.value)
      when Cel::TYPES[:uint] then Cel::Expr::Value.new(uint64_value: value.value)
      when Cel::TYPES[:double] then Cel::Expr::Value.new(double_value: value.value.to_f)
      end
    when Cel::String
      Cel::Expr::Value.new(string_value: value.value)
    when Cel::Bytes
      Cel::Expr::Value.new(bytes_value: value.value.pack("c*"))
    when Cel::Map
      entries = value.value.map do |k, v|
        { key: convert_to_conformance_value(k), value: convert_to_conformance_value(v) }
      end
      Cel::Expr::Value.new(map_value: { entries: entries })
    when Cel::List
      list_values = value.value.map { |v| convert_to_conformance_value(v) }
      Cel::Expr::Value.new(list_value: { values: list_values })
    when Cel::Types::Message
      Cel::Expr::Value.new(object_value: Google::Protobuf::Any.pack(value.message))
    when Cel::Type
      Cel::Expr::Value.new(type_value: value.to_s)
    else
      raise "Unexpected type: #{value.inspect} (#{value.class.name})"
    end
  end
end

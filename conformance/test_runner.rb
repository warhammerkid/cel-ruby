$:.unshift(__dir__)
$:.unshift(File.expand_path("../lib", __dir__))

require "cel"
require "cel/expr/conformance/test/simple_pb"
require "cel/expr/conformance/proto2/test_all_types_pb"
require "cel/expr/conformance/proto3/test_all_types_pb"

class ConformanceTestRunner
  PRIMITIVE_TYPE_MAP = {
    BOOL: :bool,
    INT64: :int,
    UINT64: :uint,
    DOUBLE: :double,
    STRING: :string,
    BYTES: :bytes,
  }.freeze

  def initialize(directory, skip_tests: [])
    @directory = directory
    @skip_tests = skip_tests
  end

  def run
    Dir[File.join(@directory, "*.json")].each do |path|
      json = File.binread(path)
      simple_test_file = Cel::Expr::Conformance::Test::SimpleTestFile.decode_json(json)
      run_test_file(simple_test_file)
    end
  end

  private

  def run_test_file(simple_test_file)
    simple_test_file.section.each do |section|
      section.test.each do |test|
        test_path = "#{simple_test_file.name}/#{section.name}/#{test.name}"
        next if @skip_tests.any? { |sp| File.fnmatch(sp, test_path) }

        # Parse
        ast = Cel::Parser.new.parse(test.expr)

        # Check
        declarations = build_declarations(test.type_env)
        Cel::Checker.new(declarations).check(ast) unless test.disable_check

        # Evaluate
        begin
          bindings = test.bindings.map do |name, binding|
            [name.to_sym, convert_conformance_value(binding.value)]
          end.to_h
          context = Cel::Context.new(declarations, bindings)
          return_value = Cel::Program.new(context).evaluate(ast)
          expr_value = convert_to_conformance_value(return_value)
  
          if expr_value != test.value
            raise ValueError.new(test.value, expr_value)
          end
        rescue => e
          # Check if we were supposed to have an evaluation error and ignore
          next if test.eval_error && Cel::EvaluateError === e

          # Otherwise log out error
          puts "Failed: #{test_path}\n#{test.description}"
          puts test.inspect

          if e.is_a?(ValueError)
            puts "Expected (json): #{e.expected.to_json}"
            puts "Actual (json): #{e.actual.to_json}"
          end

          e.backtrace.delete_if { |b| b =~ /rake/i }
          e.backtrace.delete_if { |b| b.include?(__FILE__) }
          puts e.full_message
          exit 0
        end
      end
    end
  end

  # Converts Cel::Expr::Decl protos into a declarations hash
  #
  def build_declarations(test_declarations)
    declarations = test_declarations.map do |decl|
      if decl.decl_kind == :ident
        [decl.name.to_sym, convert_conformance_type(decl.ident.type)]
      else
        raise "Cannot declare function: #{decl.inspect}"
      end
    end.to_h
  end

  # Converts Cel::Expr::Type proto into Cel::Type
  #
  def convert_conformance_type(type_proto)
    case type_proto.type_kind
    when :primitive
      PRIMITIVE_TYPE_MAP.fetch(type_proto.primitive)
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
    when Cel::Type
      Cel::Expr::Value.new(type_value: value.to_s)
    else
      puts "Unexptected type: #{value.inspect} (#{value.class.name})"
      exit 0
    end
  end

  class ValueError < StandardError
    attr_reader :expected, :actual

    def initialize(expected, actual)
      @expected = expected
      @actual = actual
      super("Actual value does not match expected value")
    end
  end
end

# frozen_string_literal: true

require "cel/program/standard_functions"
require "cel/program/comprehension"

module Cel
  class Program
    def initialize(context)
      @context = context
    end

    def evaluate(ast)
      case ast
      when AST::Literal then evaluate_literal(ast)
      when AST::Identifier then evaluate_identifier(ast)
      when AST::Select then evaluate_select(ast)
      when AST::Call then evaluate_call(ast)
      when AST::CreateList then evaluate_create_list(ast)
      when AST::CreateStruct then evaluate_create_struct(ast)
      when AST::Comprehension then evaluate_comprehension(ast)
      else
        raise "Unexpected AST node"
      end
    end

    alias_method :call, :evaluate

    private

    def evaluate_literal(ast)
      case ast.type
      when :int, :uint, :double
        Cel::Number.new(ast.type, ast.value)
      when :bool
        Cel::Bool.new(ast.value)
      when :string
        Cel::String.new(ast.value)
      when :bytes
        Cel::Bytes.new(ast.value)
      when :null
        Cel::Null.new
      else
        raise "Unexpected literal type: #{ast.inspect}"
      end
    end

    def evaluate_identifier(ast)
      if Cel::PRIMITIVE_TYPES.include?(ast.name.to_sym)
        type_sym = ast.name.to_sym
        Cel::TYPES.fetch(type_sym) { Type.new(type_sym) } # Fallback for collection types
      else
        @context.lookup(Cel::Identifier.new(ast.name))
      end
    end

    def evaluate_select(ast)
      operand = evaluate(ast.operand)
      if ast.test_only
        case operand
        when Cel::Message
          raise NoSuchFieldError.new(operand, ast.field) unless operand.field?(ast.field)

          Cel::Bool.new(!operand.public_send(ast.field).nil?)
        when Cel::Map
          Cel::Bool.new(operand.respond_to?(ast.field))
        else
          raise EvaluateError, "select is not supported on: #{operand}"
        end
      else
        case operand
        when Cel::Message, Cel::Map
          operand.public_send(ast.field)
        when Protobuf::EnumLookup
          operand.select(ast.field)
        else
          raise EvaluateError, "select is not supported on: #{operand}"
        end
      end
    end

    def evaluate_call(ast)
      args = ast.args.map { |arg| evaluate(arg) }
      target = evaluate(ast.target) if ast.target
      if (func = StandardFunctions.lookup_function(ast))
        args.unshift(target) if ast.target
        func.call(*args)
      elsif ast.function == "&&"
        Cel::Bool.new(args.all? { |x| true == x.value }) # rubocop:disable Style/YodaCondition
      elsif ast.function == "||"
        Cel::Bool.new(args.any? { |x| true == x.value }) # rubocop:disable Style/YodaCondition
      elsif @context.declarations && @context.declarations.key?(ast.function.to_sym)
        function = @context.declarations[ast.function.to_sym]
        function.call(*args.map(&:to_ruby_type))
      elsif target
        val = target.public_send(ast.function, *args)
        Cel::Literal.to_cel_type(val)
      else
        raise EvaluateError, "unhandled call: #{ast.inspect}"
      end
    end

    def evaluate_create_list(ast)
      Cel::List.new(ast.elements.map { |e| evaluate(e) })
    end

    def evaluate_create_struct(ast)
      if ast.message_name == ""
        hash = ast.entries.to_h { |entry| [evaluate(entry.key), evaluate(entry.value)] }
        Cel::Map.new(hash)
      else
        hash = ast.entries.to_h { |entry| [Cel::Identifier.new(entry.key), evaluate(entry.value)] }
        hash = nil if hash.empty? # Hack to get around bugs in protobuf wrapper type code
        Cel::Message.new(Cel::Identifier.new(ast.message_name), hash)
      end
    end

    def evaluate_comprehension(ast)
      Comprehension.new(@context, ast).call
    end
  end
end

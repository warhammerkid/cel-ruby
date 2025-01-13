# frozen_string_literal: true

require "cel/program/comprehension"

module Cel
  class Program
    def initialize(context, container)
      @context = context
      @container = container
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
      name_sym = ast.name.to_sym
      if Cel::PRIMITIVE_TYPES.include?(name_sym)
        Cel::TYPES.fetch(name_sym)
      else
        @context.lookup(ast.name)
      end
    end

    def evaluate_select(ast)
      operand = evaluate(ast.operand)
      if ast.test_only
        raise EvaluateError, "select is not supported on: #{operand}" unless operand.respond_to?(:field_set?)

        operand.field_set?(ast.field)

      else
        case operand
        when Cel::Map
          operand[Cel::String.new(ast.field)]
        when Cel::Message
          operand[ast.field]
        when Protobuf::EnumLookup
          operand.select(ast.field)
        else
          raise EvaluateError, "select is not supported on: #{operand}"
        end
      end
    end

    def evaluate_call(ast)
      args = ast.args.map { |arg| evaluate(arg) }
      args.unshift(evaluate(ast.target)) if ast.target

      if (binding = @context.lookup_function(ast, args))
        binding.call(*args)
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
      elsif !defined?(Cel::Message)
        warn "DEPRECATED: Use of named structs without protobufs is deprecated"
        hash = ast.entries.to_h { |entry| [Cel::String.new(entry.key), evaluate(entry.value)] }
        Cel::Map.new(hash)
      else
        # Look up descriptor in the protobuf pool
        pool = Google::Protobuf::DescriptorPool.generated_pool
        qualified_names = @container.resolve(ast.message_name)
        qualified_name = qualified_names.find { |name| pool.lookup(name) }
        raise EvaluateError, "unknown type: #{ast.message_name}" unless qualified_name

        # Build the protobuf message
        hash = ast.entries.to_h { |entry| [entry.key, evaluate(entry.value)] }
        Cel::Message.from_cel_fields(pool.lookup(qualified_name), hash)
      end
    end

    def evaluate_comprehension(ast)
      Comprehension.new(@context, @container, ast).call
    end
  end
end

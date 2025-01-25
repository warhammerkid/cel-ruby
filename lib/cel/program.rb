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
      return Cel::TYPES.fetch(name_sym) if Cel::PRIMITIVE_TYPES.include?(name_sym)

      @container.resolve(ast.name).each do |candidate_name|
        value = @context.lookup(candidate_name)
        return value unless value.nil?
      end

      raise EvaluateError, "no value in context for #{ast.name}"
    end

    def evaluate_select(ast)
      # Handle test_only (has macro)
      if ast.test_only
        operand = evaluate(ast.operand)
        raise EvaluateError, "select is not supported on: #{operand}" unless operand.respond_to?(:field_set?)

        return operand.field_set?(ast.field)
      end

      # Is this a qualified ident?
      if (name = get_qualified_name(ast))
        @container.resolve(name).each do |candidate_name|
          value = @context.lookup(candidate_name)
          return value unless value.nil?
        end
      end

      # Treat it as a normal select
      operand = evaluate(ast.operand)
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

    def evaluate_call(ast)
      # Does it have a qualified name?]
      function_name = ast.function
      target = ast.target
      if (name = get_qualified_name(target))
        @container.resolve("#{name}.#{function_name}").each do |candidate_name|
          next unless @context.function_defined?(candidate_name)

          # Found a matching qualified name
          function_name = candidate_name
          target = nil
          break
        end
      end

      # Lookup actual function binding
      args = ast.args.map { |arg| evaluate(arg) }
      args.unshift(evaluate(target)) if target
      if (binding = @context.lookup_function(function_name, !target.nil?, args))
        return binding.call(*args)
      end

      raise EvaluateError, "unhandled call: #{ast.inspect}"
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

    # Returns a string concatenating all chained ident/selects together with
    # period separators. Returns nil if the given ast node isn't a chain of
    # only idents and selects.
    def get_qualified_name(ast)
      case ast
      when AST::Identifier
        ast.name
      when AST::Select
        operand = get_qualified_name(ast.operand)
        operand ? "#{operand}.#{ast.field}" : nil
      end
    end
  end
end

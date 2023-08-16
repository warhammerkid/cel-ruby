# frozen_string_literal: true

module Cel
  class Program
    def initialize(context)
      @context = context
    end

    def evaluate(ast)
      case ast
      when Group
        evaluate(ast.value)
      when Invoke
        evaluate_invoke(ast)
      when Operation
        evaluate_operation(ast)
      when Message
        ast.struct
      when Literal
        evaluate_literal(ast)
      when Identifier
        evaluate_identifier(ast)
      when Condition
        evaluate_condition(ast)
      end
    end

    alias_method :call, :evaluate

    private

    def evaluate_identifier(identifier)
      if Cel::PRIMITIVE_TYPES.include?(identifier.to_sym)
        TYPES[identifier.to_sym]
      else
        @context.lookup(identifier)
      end
    end

    def evaluate_literal(val)
      case val
      when List
        List.new(val.value.map(&method(:call)))
      else
        val
      end
    end

    def evaluate_operation(operation)
      op = operation.op

      values = operation.operands.map do |operand|
        ev_operand = call(operand)

        # return ev_operand if op == "||" && ev_operand == true

        ev_operand
      end

      if operation.unary? &&
         op != "!" # https://bugs.ruby-lang.org/issues/18246
        # unary operations
        Literal.to_cel_type(values.first.__send__(:"#{op}@"))
      elsif op == "&&"
        Bool.new(values.all? { |x| true == x.value }) # rubocop:disable Style/YodaCondition
      elsif op == "||"
        Bool.new(values.any? { |x| true == x.value }) # rubocop:disable Style/YodaCondition
      elsif op == "in"
        element, collection = values
        Bool.new(collection.include?(element))
      else
        op_value, *values = values
        val = op_value.public_send(op, *values)

        Literal.to_cel_type(val)
      end
    end

    def evaluate_invoke(invoke, var = invoke.var)
      func = invoke.func
      args = invoke.args

      return evaluate_standard_func(invoke) unless var

      var = case var
            when Identifier
              evaluate_identifier(var)
            when Invoke
              evaluate_invoke(var)
            else
              var
      end

      case var
      when String
        raise EvaluateError, "#{invoke} is not supported" unless String.method_defined?(func, false)

        var.public_send(func, *args.map(&method(:call)))
      when Message
        # If e evaluates to a message and f is not declared in this message, the
        # runtime error no_such_field is raised.
        raise NoSuchFieldError.new(var, func) unless var.field?(func)

        var.public_send(func)
      when Map, List
        return Macro.__send__(func, var, *args, context: @context) if Macro.respond_to?(func)

        # If e evaluates to a map, then e.f is equivalent to e['f'] (where f is
        # still being used as a meta-variable, e.g. the expression x.foo is equivalent
        # to the expression x['foo'] when x evaluates to a map).

        args ?
        var.public_send(func, *args) :
        var.public_send(func)
      when Timestamp, Duration
        raise EvaluateError, "#{invoke} is not supported" unless var.class.method_defined?(func, false)

        var.public_send(func, *args)
      else
        raise EvaluateError, "#{invoke} is not supported"
      end
    end

    def evaluate_condition(condition)
      call(condition.if) ? call(condition.then) : call(condition.else)
    end

    def evaluate_standard_func(funcall)
      func = funcall.func
      args = funcall.args

      case func
      when :type
        val = call(args.first)
        return val.type if val.respond_to?(:type)

        val.class
      # MACROS
      when :has
        Macro.__send__(func, *args)
      when :size
        Cel::Number.new(:int, Macro.__send__(func, *args))
      when :matches
        Macro.__send__(func, *args.map(&method(:call)))
      when :int, :uint, :string, :double, :bytes, :duration, :timestamp
        type = TYPES[func]
        type.cast(call(args.first))
      when :dyn
        call(args.first)
      else
        return evaluate_custom_func(@context.declarations[func], funcall) if @context.declarations.key?(func)

        raise EvaluateError, "#{funcall} is not supported"
      end
    end

    def evaluate_custom_func(func, funcall)
      args = funcall.args

      func.call(*args.map(&method(:call)).map(&:to_ruby_type))
    end
  end
end

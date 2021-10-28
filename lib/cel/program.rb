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

    alias call evaluate

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
        val.value.map { |y| call(y) }
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


      if values.size == 1 &&
        op != "!" # https://bugs.ruby-lang.org/issues/18246
        # unary operations
        values.first.__send__(:"#{op}@")
      elsif op == "&&"
        Bool.new(values.all? { |x| x == true })
      elsif op == "||"
        Bool.new(values.any? { |x| x == true })
      elsif op == "in"
        element, collection = values
        Bool.new(collection.include?(element))
      else
        op_value, *values = values
        op_value.public_send(op, *values)
      end
    end

    def evaluate_invoke(invoke)
      var = invoke.var
      func = invoke.func
      args = invoke.args

      return evaluate_standard_func(func, args) unless var

      if Identifier === var
        var = evaluate_identifier(var)
      end

      case var
      when String
        raise Error, "#{invoke} is not supported" unless String.method_defined?(func, false)

        var.public_send(func, *args)
      when Message
        # If e evaluates to a message and f is not declared in this message, the
        # runtime error no_such_field is raised.
        raise NoSuchFieldError.new(var, func) unless var.field?(func)

        var.public_send(func)
      when Map, List
        if Macro.respond_to?(func)
          return Macro.__send__(func, var, *args, context: @context)
        end
        # If e evaluates to a map, then e.f is equivalent to e['f'] (where f is
        # still being used as a meta-variable, e.g. the expression x.foo is equivalent
        # to the expression x['foo'] when x evaluates to a map).

        args ?
        var.public_send(func, *args) :
        var.public_send(func)
      else
        raise Error, "#{invoke} is not supported"
      end
    end

    def evaluate_condition(condition)
      call(condition.if) ? call(condition.then) : call(condition.else)
    end

    def evaluate_standard_func(func, args)
      case func
      when :type
        call(args.first).type
      # MACROS
      when :has, :size
        Macro.__send__(func, *args)
      when :matches
        Macro.__send__(func, *args.map(&method(:call)))
      when :int, :uint, :string, :double, :bytes # :duration, :timestamp
        type = TYPES[func]
        type.cast(args.first)
      else
        raise Error, "#{func} is not supported"
      end
    end
  end
end
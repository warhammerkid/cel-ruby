# frozen_string_literal: true


module Cel
  class Program

    def initialize(context)
      @context = context
    end

    def evaluate(ast)
      case ast
      when Invoke
        evaluate_invoke(ast)
      when Operation
        evaluate_operation(ast)
      when Literal
        evaluate_literal(ast)
      when Identifier
        evaluate_identifier(ast)
      end
    end

    alias call evaluate

    private

    def evaluate_identifier(identifier)
      if Cel::PRIMITIVE_TYPES.include?(identifier.to_s)
        TYPES[identifier.to_sym]
      else
        @context.lookup(identifier)
      end
    end

    def evaluate_literal(val)
      case val
      when Struct
        Hash[val.value.map { |x, y| [call(x), call(y)] }]
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
        return values.all? { |x| x == true }

      elsif op == "||"
        return values.any? { |x| x == true }
      else
        op_value, *values = values
        op_value.public_send(op, *values)
      end
    end

    def evaluate_invoke(funcall)
      var = funcall.var
      func = funcall.func
      args = funcall.args

      return evaluate_standard_func(func, args) unless var

      args ?
      var.public_send(func, *args) :
      var.public_send(func)
    end

    def evaluate_standard_func(func, args)
      case func
      when :type
        if Cel::PRIMITIVE_TYPES.include?(args.to_s)
          TYPES[:type]
        else
          elem = call(args)
          elem.type
        end
      else
        raise Error, "#{func} is not supported"
      end
    end
  end
end
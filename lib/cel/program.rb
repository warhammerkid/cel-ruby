# frozen_string_literal: true


module Cel
  module Program
    module_function

    def call(ast)
      case ast
      when Invoke
        evaluation_invoke(ast)
      when Operation
        evaluate_operation(ast)
      when Literal
        evaluate_literal(ast)
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

    def evaluation_invoke(funcall)
      var = funcall.var
      func = funcall.func
      args = funcall.args
      var.public_send(func, args)
    end
  end
end
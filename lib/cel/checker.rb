module Cel
  class Checker

    def initialize(declarations)
      @declarations = declarations
    end

    def check(ast)
      case ast
      when Group
        check(ast.value)
      when Invoke
        check_invoke(ast)
      when Operation
        check_operation(ast)
      when Literal
        ast.type
      when Identifier
        check_identifier(ast)
      when Condition
        check_condition(ast)
      end
    end

    alias call check

    private

    # TODO: add protobuf timestamp and duration
    LOGICAL_EXPECTED_TYPES = %i[bool int uint double string bytes]
    ADD_EXPECTED_TYPES = %i[int uint double string bytes list]
    SUB_EXPECTED_TYPES = %i[int uint double]
    MULTIDIV_EXPECTED_TYPES = %i[int uint double]
    REMAINDER_EXPECTED_TYPES = %i[int uint]

    def check_operation(operation)
      op = operation.op

      values = operation.operands.map do |operand|
        ev_operand = call(operand)

        return :any if ev_operand == :any && !%w[&& || == != < <= >= >].include?(op)

        ev_operand
      end

      if values.size == 1
        type = values.first
        case op
        when "!"
          return type if type == :bool

          unsupported_type(op, type)
        when "-"
          case type
          when :int, :bool
            type
          else
            unsupported_type(op, type)
          end
        else
          unsupported_operation("#{op}(#{type})")
        end
      else

        case op
        when "&&", "||", "==", "!=", "<", "<=", ">=", ">"
          TYPES[:bool]
        when "+"
          verify_all_match_type?(op, ADD_EXPECTED_TYPES, values)

          values.first
        when "-"
          verify_all_match_type?(op, SUB_EXPECTED_TYPES, values)

          values.first
        when "*", "/"
          verify_all_match_type?(op, MULTIDIV_EXPECTED_TYPES, values)

          values.first
        when "%"
          verify_all_match_type?(op, REMAINDER_EXPECTED_TYPES, values)

          values.first
        else
          unsupported_operation(values.join(" #{op} "))
        end
      end
    end

    def check_invoke(funcall)
      var = funcall.var
      func = funcall.func
      args = funcall.args

      return check_standard_func(func, args) unless var

      case var.type
      when MapType
        # A field selection expression, e.f, can be applied both to messages and
        # to maps. For maps, selection is interpreted as the field being a string key.
        attrib = func == :[] ? args : func
        attribute = var.type.get(attrib)
        unsupported_operation("#{var}.#{attrib}") unless attribute

        call(attribute)
      when ListType
        case func
        when :[]
          call(var.type.get(args))
        else
          unsupported_operation("#{var}.#{func}")
        end
      else
        :any
      end
    end

    def check_standard_func(func, args)
      case func
      when :type
        TYPES[:type]
      else
        raise Error, "#{func} is not supported"
      end
    end

    def check_identifier(identifier)
      return unless identifier.type == :any

      if Cel::PRIMITIVE_TYPES.include?(identifier.to_sym)
        return TYPES[:type]
      end

      id_type = infer_dec_type(identifier.id)

      return :any unless id_type

      identifier.type = id_type
    end

    def check_condition(condition)
      then_type = call(condition.then)
      else_type = call(condition.else)

      return then_type if then_type == else_type

      :any
    end

    def infer_dec_type(id)
      return unless @declarations

      var_name, *id_call_chain = id.split(".").map(&:to_sym)

      typ = @declarations[var_name]

      return unless typ

      return convert(typ) if id_call_chain.empty?
    end

    def convert(typ)
      case typ
      when Type
        typ
      when Symbol
        Types[typ]
      else
        raise Error, "can't convert #{typ}"
      end
    end


    def verify_all_match_type?(op, expected, values)
      # at least an expected type must match all values
      return if expected.any? { |expected_type|
        values.all? { |type| type == expected_type } }

      raise unsupported_operation(values.join(" #{op} "))
    end

    def unsupported_type(op, type)
      raise Error, "unsupported type (#{type}) for operation (#{op})"
    end

    def unsupported_operation(op)
      raise Error, "unsupported operation (#{op})"
    end
  end
end
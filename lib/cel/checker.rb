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

    def merge(declarations)
      Checker.new(@declarations ? @declarations.merge(declarations) : declarations)
    end

    # TODO: add protobuf timestamp and duration
    LOGICAL_EXPECTED_TYPES = %i[bool int uint double string bytes]
    ADD_EXPECTED_TYPES = %i[int uint double string bytes list]
    SUB_EXPECTED_TYPES = %i[int uint double]
    MULTIDIV_EXPECTED_TYPES = %i[int uint double]
    REMAINDER_EXPECTED_TYPES = %i[int uint]

    def check_operation(operation)
      type = infer_operation_type(operation)
      operation.type = type
      type
    end

    def infer_operation_type(operation)
      op = operation.op

      values = operation.operands.map do |operand|
        ev_operand = call(operand)

        return TYPES[:any] if ev_operand == :any && !%w[&& || == != < <= >= >].include?(op)

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
          return TYPES[:bool]
        when "in"
          if find_match_all_types(%i[list map], values.last)
            return TYPES[:bool]
          end
        when "+"
          if (type = find_match_all_types(ADD_EXPECTED_TYPES, values))
            return type
          end
        when "-"
          if (type = find_match_all_types(SUB_EXPECTED_TYPES, values))
            return type
          end
        when "*", "/"
          if (type = find_match_all_types(MULTIDIV_EXPECTED_TYPES, values))
            return type
          end
        when "%"
          if (type = find_match_all_types(REMAINDER_EXPECTED_TYPES, values))
            return type
          end
        else
          unsupported_operation(values.join(" #{op} "))
        end

        unsupported_operation(values.join(" #{op} "))
      end
    end

    def check_invoke(funcall)
      var = funcall.var
      func = funcall.func
      args = funcall.args

      return check_standard_func(funcall) unless var

      if Identifier === var
        check_identifier(var)
      end

      case var.type
      when MapType
        # A field selection expression, e.f, can be applied both to messages and
        # to maps. For maps, selection is interpreted as the field being a string key.
        case func
        when :[]
          attribute = var.type.get(args)
          unsupported_operation(funcall) unless attribute
        when :all, :exists, :exists_one
          check_arity(funcall, args, 2)
          identifier, predicate = args

          unsupported_operation(funcall) if !identifier.is_a?(Identifier)

          element_checker = merge(identifier.to_sym => var.type.element_type)

          unsupported_operation(funcall) if element_checker.check(predicate) != :bool

          return TYPES[:bool]
        else
          attribute = var.type.get(func)
          unsupported_operation(funcall) unless attribute
        end

        call(attribute)
      when ListType
        case func
        when :[]
          attribute = var.type.get(args)
          unsupported_operation(funcall) unless attribute
          call(attribute)
        when :all, :exists, :exists_one
          check_arity(funcall, args, 2)
          identifier, predicate = args

          unsupported_operation(funcall) if !identifier.is_a?(Identifier)

          element_checker = merge(identifier.to_sym => var.type.element_type)

          unsupported_operation(funcall) if element_checker.check(predicate) != :bool

          return TYPES[:bool]
        when :filter
          check_arity(funcall, args, 2)
          identifier, predicate = args

          unsupported_operation(funcall) if !identifier.is_a?(Identifier)

          element_checker = merge(identifier.to_sym => var.type.element_type)

          unsupported_operation(funcall) if element_checker.check(predicate) != :bool

          return var.type
        when :map
          check_arity(funcall, args, 2)
          identifier, predicate = args

          unsupported_operation(funcall) if !identifier.is_a?(Identifier)

          element_checker = merge(identifier.to_sym => var.type.element_type)

          type = var.type
          type.element_type = element_checker.check(predicate)
          return type
        else
          unsupported_operation(funcall)
        end
      when TYPES[:string]
        case func
        when :contains, :endsWith, :startsWith
          check_arity(funcall, args, 1)
          if find_match_all_types(%i[string], call(args.first))
            return TYPES[:bool]
          end
        when :matches
          check_arity(funcall, args, 1)
          # TODO: verify if string can be transformed into a regex
          if find_match_all_types(%i[string], call(args.first))
            return TYPES[:bool]
          end
        else
          unsupported_operation(funcall)
        end
        unsupported_operation("#{var}.#{func}")
      else
        TYPES[:any]
      end
    end

    CAST_ALLOWED_TYPES = {
      int: %i[uint double string], # TODO: enum, timestamp
      uint: %i[int double string],
      string: %i[int uint double bytes], # TODO: timestamp, duration
      double: %i[int uint string],
      bytes: %i[string],
    }

    def check_standard_func(funcall)
      func = funcall.func
      args = funcall.args

      case func
      when :type
        check_arity(func, args, 1)
        return TYPES[:type]
      when :has
        check_arity(func, args, 1)
        unless args.first.is_a?(Invoke)
          raise unsupported_operation(funcall)
        end

        return TYPES[:bool]
      when :size
        check_arity(func, args, 1)
        if find_match_all_types(%i[string bytes list map], call(args.first))
          return TYPES[:int]
        end
      when :int, :uint, :string, :double, :bytes # :duration, :timestamp
        check_arity(func, args, 1)
        allowed_types = CAST_ALLOWED_TYPES[func]

        if find_match_all_types(allowed_types, call(args.first))
          return TYPES[func]
        end
      when :matches
        check_arity(func, args, 2)
        if find_match_all_types(%i[string], args.map(&method(:call)))
          return TYPES[:bool]
        end
      when :dyn
        check_arity(func, args, 1)
        arg_type = call(args.first)
        case arg_type
        when ListType, MapType
          arg_type.element_type = TYPES[:any]
          return arg_type
        else
          return arg_type
        end
      else
        unsupported_operation(funcall)
      end

      unsupported_operation(funcall)
    end

    def check_identifier(identifier)
      return unless identifier.type == :any

      if Cel::PRIMITIVE_TYPES.include?(identifier.to_sym)
        return TYPES[:type]
      end

      id_type = infer_dec_type(identifier.id)

      return TYPES[:any] unless id_type

      identifier.type = id_type
    end

    def check_condition(condition)
      then_type = call(condition.then)
      else_type = call(condition.else)

      return then_type if then_type == else_type

      TYPES[:any]
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


    def find_match_all_types(expected, types)
      # at least an expected type must match all values
      type = expected.find do |expected_type|
        case types
        when Array
          types.all? { |type| type == expected_type }
        else
          types == expected_type
        end
      end

      TYPES[type]
    end

    def check_arity(func, args, arity)
      return if args.size == arity

      raise Error, "`#{func}` invoked with wrong number of arguments (should be #{arity})"
    end

    def unsupported_type(op, type)
      raise Error, "unsupported type (#{type}) for operation (#{op})"
    end

    def unsupported_operation(op)
      raise Error, "unsupported operation (#{op})"
    end
  end
end
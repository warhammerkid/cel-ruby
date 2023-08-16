# frozen_string_literal: true

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

    alias_method :call, :check

    private

    def merge(declarations)
      Checker.new(@declarations ? @declarations.merge(declarations) : declarations)
    end

    LOGICAL_EXPECTED_TYPES = %i[bool int uint double string bytes timestamp duration].freeze
    ADD_EXPECTED_TYPES = %i[int uint double string bytes list duration].freeze
    SUB_EXPECTED_TYPES = %i[int uint double duration].freeze
    MULTIDIV_EXPECTED_TYPES = %i[int uint double].freeze
    REMAINDER_EXPECTED_TYPES = %i[int uint].freeze

    def check_operation(operation)
      type = infer_operation_type(operation)
      operation.type = type
      type
    end

    BOOLABLE_OPERATORS = %w[&& || == != < <= >= >].freeze

    def infer_operation_type(operation)
      op = operation.op

      values = operation.operands.map do |operand|
        ev_operand = call(operand)

        return TYPES[:any] if ev_operand == :any && !BOOLABLE_OPERATORS.include?(op)

        ev_operand
      end

      if values.size == 1
        # unary ops
        type = values.first
        case op
        when "!"
          return type if type == :bool

        when "-"
          return type if type == :int || type == :double # rubocop:disable Style/MultipleComparison

        else
          unsupported_type(operation)
        end
      else

        case op
        when "&&", "||", "<", "<=", ">=", ">"
          return TYPES[:bool] if find_match_all_types(LOGICAL_EXPECTED_TYPES, values) || values.include?(:any)
        when "!=", "=="
          return TYPES[:bool] if values.uniq.size == 1 ||
                                 values.all? { |v| v == :list } ||
                                 values.all? { |v| v == :map } ||
                                 values.include?(:any)
        when "in"
          return TYPES[:bool] if find_match_all_types(%i[list map any], values.last)
        when "+"
          return type if (type = find_match_all_types(ADD_EXPECTED_TYPES, values))

          return TYPES[:timestamp] if %i[timestamp duration].any? { |typ| values.first == typ }

          return values.last if values.first == :any

        when "-"
          return type if (type = find_match_all_types(SUB_EXPECTED_TYPES, values))

          case values.first
          when TYPES[:timestamp]
            return TYPES[:duration] if values.last == :timestamp

            return TYPES[:timestamp] if values.last == :duration

            return TYPES[:any] if values.last == :any

          when TYPES[:any]
            return values.last
          end
        when "*", "/"
          return type if (type = find_match_all_types(MULTIDIV_EXPECTED_TYPES, values))

          values.include?(:any)
          values.find { |typ| typ != :any } || TYPES[:any]

        when "%"
          return type if (type = find_match_all_types(REMAINDER_EXPECTED_TYPES, values))

          values.include?(:any)
          values.find { |typ| typ != :any } || TYPES[:any]

        else
          unsupported_type(operation)
        end
      end
      unsupported_type(operation)
    end

    def infer_variable_type(var)
      case var
      when Identifier
        check_identifier(var)
      when Invoke
        check_invoke(var)
      else
        var.type
      end
    end

    def check_invoke(funcall, var_type = nil)
      var = funcall.var
      func = funcall.func
      args = funcall.args

      return check_standard_func(funcall) unless var

      var_type ||= infer_variable_type(var)

      case var_type
      when MapType
        # A field selection expression, e.f, can be applied both to messages and
        # to maps. For maps, selection is interpreted as the field being a string key.
        case func
        when :[]
          attribute = var_type.get(args)
          return TYPES[:any] unless attribute
        when :all, :exists, :exists_one
          check_arity(funcall, args, 2)
          identifier, predicate = args

          unsupported_type(funcall) unless identifier.is_a?(Identifier)

          element_checker = merge(identifier.to_sym => var_type.element_type)

          unsupported_type(funcall) if element_checker.check(predicate) != :bool

          return TYPES[:bool]
        else
          attribute = var_type.get(func)
          return TYPES[:any] unless attribute
        end

        call(attribute)
      when ListType
        case func
        when :[]
          attribute = var_type.get(args)
          unsupported_operation(funcall) unless attribute
          call(attribute)
        when :all, :exists, :exists_one
          check_arity(funcall, args, 2)
          identifier, predicate = args

          unsupported_type(funcall) unless identifier.is_a?(Identifier)

          identifier.type = var_type.element_type

          element_checker = merge(identifier.to_sym => var_type.element_type)

          unsupported_type(funcall) if element_checker.check(predicate) != :bool

          TYPES[:bool]
        when :filter
          check_arity(funcall, args, 2)
          identifier, predicate = args

          unsupported_type(funcall) unless identifier.is_a?(Identifier)

          element_checker = merge(identifier.to_sym => var_type.element_type)

          unsupported_type(funcall) if element_checker.check(predicate) != :bool

          var_type
        when :map
          check_arity(funcall, args, 2)
          identifier, predicate = args

          unsupported_type(funcall) unless identifier.is_a?(Identifier)

          element_checker = merge(identifier.to_sym => var_type.element_type)

          var_type.element_type = element_checker.check(predicate)
          var_type
        else
          unsupported_operation(funcall)
        end
      when TYPES[:string]
        case func
        when :contains, :endsWith, :startsWith
          check_arity(funcall, args, 1)
          return TYPES[:bool] if find_match_all_types(%i[string], call(args.first))
        when :matches # rubocop:disable Lint/DuplicateBranch
          check_arity(funcall, args, 1)
          # TODO: verify if string can be transformed into a regex
          return TYPES[:bool] if find_match_all_types(%i[string], call(args.first))
        else
          unsupported_type(funcall)
        end
        unsupported_operation(funcall)
      when TYPES[:timestamp]
        case func
        when :getDate, :getDayOfMonth, :getDayOfWeek, :getDayOfYear, :getFullYear, :getHours,
             :getMilliseconds, :getMinutes, :getMonth, :getSeconds
          check_arity(func, args, 0..1)
          return TYPES[:int] if args.empty? || (args.size.positive? && args[0] == :string)
        else
          unsupported_type(funcall)
        end
        unsupported_operation(funcall)
      when TYPES[:duration]
        case func
        when :getMilliseconds, :getMinutes, :getHours, :getSeconds
          check_arity(func, args, 0)
          return TYPES[:int]
        else
          unsupported_type(funcall)
        end
        unsupported_operation(funcall)
      else
        TYPES[:any]
      end
    end

    CAST_ALLOWED_TYPES = {
      int: %i[uint double string timestamp], # TODO: enum
      uint: %i[int double string],
      string: %i[int uint double bytes timestamp duration],
      double: %i[int uint string],
      bytes: %i[string],
      duration: %i[string],
      timestamp: %i[string],
    }.freeze

    def check_standard_func(funcall)
      func = funcall.func
      args = funcall.args

      case func
      when :type
        check_arity(func, args, 1)
        return TYPES[:type]
      when :has
        check_arity(func, args, 1)
        unsupported_type(funcall) unless args.first.is_a?(Invoke)

        return TYPES[:bool]
      when :size
        check_arity(func, args, 1)

        arg = call(args.first)
        return TYPES[:int] if find_match_all_types(%i[string bytes list map], arg)
      when *CAST_ALLOWED_TYPES.keys
        check_arity(func, args, 1)
        allowed_types = CAST_ALLOWED_TYPES[func]

        arg = call(args.first)
        return TYPES[func] if find_match_all_types(allowed_types, arg)
      when :matches
        check_arity(func, args, 2)
        return TYPES[:bool] if find_match_all_types(%i[string], args.map(&method(:call)))
      when :dyn
        check_arity(func, args, 1)
        arg_type = call(args.first)
        case arg_type
        when ListType, MapType
          arg_type.element_type = TYPES[:any]
        end
        return arg_type
      else
        return check_custom_func(@declarations[func], funcall) if @declarations.key?(func)

        unsupported_type(funcall)
      end

      unsupported_operation(funcall)
    end

    def check_custom_func(func, funcall)
      args = funcall.args

      unless func.is_a?(Cel::Function)
        raise CheckError, "#{func} must respond to #call" unless func.respond_to?(:call)

        func = Cel::Function(&func)
      end

      unless func.types.empty?
        unsupported_type(funcall) unless func.types.zip(args.map(&method(:call)))
                                             .all? do |expected_type, type|
                                               expected_type == :any || expected_type == type
                                             end

        return func.type
      end

      unsupported_operation(funcall)
    end

    def check_identifier(identifier)
      return identifier.type unless identifier.type == :any

      return TYPES[:type] if Cel::PRIMITIVE_TYPES.include?(identifier.to_sym)

      id_type = infer_dec_type(identifier.id)

      return TYPES[:any] unless id_type

      identifier.type = id_type

      id_type
    end

    def check_condition(condition)
      if_type = call(condition.if)

      raise CheckError, "`#{condition.if}` must evaluate to a bool" unless if_type == :bool

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

      convert(typ) if id_call_chain.empty?
    end

    def convert(typ)
      case typ
      when Symbol
        TYPES[typ] or
          raise CheckError, "#{typ} is not a valid type"
      else
        typ
      end
    end

    def find_match_all_types(expected, types)
      # at least an expected type must match all values
      type = expected.find do |expected_type|
        case types
        when Array
          types.all? { |typ| typ == expected_type }
        else
          types == expected_type
        end
      end

      type && types.is_a?(Type) ? types : TYPES[type]
    end

    def check_arity(func, args, arity)
      return if arity === args.size # rubocop:disable Style/CaseEquality

      raise CheckError, "`#{func}` invoked with wrong number of arguments (should be #{arity})"
    end

    def unsupported_type(op)
      raise NoMatchingOverloadError, op
    end

    def unsupported_operation(op)
      raise CheckError, "unsupported operation (#{op})"
    end
  end
end

# frozen_string_literal: true

module Cel
  class Program
    module StandardFunctions
      BINARY_OPERATORS = [
        "+", "-", "*", "/", "%",
        "<=", ">=", "<", ">", "==", "!="
      ].freeze
      TYPE_CAST = %w[
        int uint double string bytes bool duration timestamp
      ].freeze

      class << self
        def lookup_function(call_ast)
          if call_ast.function == "size"
            method(:size) # Either global or receiver - doesn't matter
          elsif call_ast.function == "matches"
            method(:matches) # Either global or receiver - doesn't matter
          elsif call_ast.target.nil?
            lookup_global_function(call_ast)
          end
        end

        def lookup_global_function(call_ast)
          if call_ast.args.size == 1
            case call_ast.function
            when "!" then method(:unary_not)
            when "-" then method(:unary_negate)
            when "dyn" then method(:dyn)
            when "type" then method(:type)
            when "@not_strictly_false" then method(:not_strictly_false)
            when *TYPE_CAST then method(call_ast.function)
            end
          elsif call_ast.args.size == 2
            if BINARY_OPERATORS.include?(call_ast.function)
              method(call_ast.function)
            elsif call_ast.function == "[]"
              method(:index_lookup)
            elsif call_ast.function == "in"
              method(:in)
            end
          elsif call_ast.function == "?:" && call_ast.args.size == 3
            method(:ternary_condition)
          end
        end

        def dyn(a)
          a
        end

        def type(a)
          return a.type if a.respond_to?(:type)

          a.class
        end

        def size(a)
          Cel::Number.new(:int, a.size)
        end

        def matches(string, pattern)
          pattern = Regexp.new(pattern)
          Bool.new(pattern.match?(string.value))
        end

        def ternary_condition(condition, a, b)
          condition.value ? a : b
        end

        def unary_not(a)
          !a
        end

        def unary_negate(a)
          Cel::Literal.to_cel_type(-a)
        end

        def index_lookup(obj, index)
          case obj
          when Cel::List
            raise EvaluateError, "Index must be a number" unless index.is_a?(Cel::Number)
            raise EvaluateError, "Index out of bounds" if index.value.negative? || index.value >= obj.size

            obj[index.value]
          when Cel::Map then obj.fetch(index)
          else raise EvaluateError, "Cannot perform index lookup on: #{obj}"
          end
        end

        def in(element, collection)
          Cel::Bool.new(collection.include?(element))
        end

        # Internal helper method used for comprehension loop conditions
        def not_strictly_false(value)
          value.is_a?(Cel::Bool) ? value : Cel::Bool.new(true)
        end

        BINARY_OPERATORS.each do |operator|
          operator_sym = operator.to_sym
          define_method(operator_sym) do |a, b|
            Cel::Literal.to_cel_type(a.public_send(operator_sym, b))
          end
        end

        TYPE_CAST.each do |function|
          define_method(function) do |a|
            TYPES.fetch(function.to_sym).cast(a)
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Cel
  module AST
    class Expr; end # rubocop:disable Lint/EmptyClass

    # This is not necessary for an ANTLR4 parser, but is needed to support the
    # negative number optimization for a LALR parser. These are removed during
    # tree optimization.
    class Nested < Expr
      attr_accessor :expr

      def initialize(expr)
        super()
        @expr = expr
      end

      def ==(other)
        other.is_a?(Nested) && @expr == other.expr
      end
    end

    # Matches up to cel.expr.Constant in cel/expr/syntax.proto
    class Literal < Expr
      attr_accessor :type, :value

      def initialize(type, value)
        super()
        @type = type
        @value = value
      end

      def ==(other)
        other.is_a?(Literal) && @type == other.type && @value == other.value
      end
    end

    # Matches up to cel.expr.Expr.Ident in cel/expr/syntax.proto
    class Identifier < Expr
      attr_accessor :name

      def initialize(name)
        super()
        @name = name
      end

      def ==(other)
        other.is_a?(Identifier) && @name == other.name
      end
    end

    # Matches up to cel.expr.Expr.Select in cel/expr/syntax.proto
    class Select < Expr
      attr_accessor :operand, :field, :test_only

      def initialize(operand, field, test_only: false)
        super()
        @operand = operand
        @field = field
        @test_only = test_only # Use for has() macro expansion
      end

      def ==(other)
        other.is_a?(Select) && @operand == other.operand && @field == other.field \
          && @test_only == other.test_only
      end
    end

    # Matches up to cel.expr.Expr.Call in cel/expr/syntax.proto
    class Call < Expr
      attr_accessor :target, :function, :args

      def initialize(target, function, args)
        super()
        @target = target
        @function = function
        @args = args
      end

      def ==(other)
        other.is_a?(Call) && @target == other.target && @function == other.function \
          && @args == other.args
      end
    end

    # Matches up to cel.expr.Expr.CreateList in cel/expr/syntax.proto
    class CreateList < Expr
      attr_accessor :elements

      def initialize(elements)
        super()
        @elements = elements
      end

      def ==(other)
        other.is_a?(CreateList) && @elements == other.elements
      end
    end

    Entry = Struct.new("Entry", :key, :value)

    # Matches up to cel.expr.Expr.CreateStruct in cel/expr/syntax.proto
    class CreateStruct < Expr
      attr_accessor :message_name, :entries

      def initialize(message_name, entries)
        super()
        @message_name = message_name
        @entries = entries
      end

      def ==(other)
        other.is_a?(CreateStruct) && @message_name == other.message_name \
          && @entries == other.entries
      end
    end
  end
end

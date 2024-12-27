# frozen_string_literal: true

module Cel
  module Macro
    ACCUMULATOR_NAME = "__result__"

    def self.rewrite_global(function, args)
      case function
      when "has" then rewrite_has(args)
      end
    end

    def self.rewrite_receiver(target, function, args)
      case function
      when "all" then rewrite_all(target, args)
      end
    end

    def self.rewrite_has(args)
      unless args.size == 1 && args[0].is_a?(Cel::AST::Select)
        raise Cel::ParseError, "has() macro expects select argument"
      end

      args[0].tap { |s| s.test_only = true }
    end

    # Expands the expression into a comprehension that returns true if all of
    # the elements in the range match the predicate expression:
    #
    #   <iterRange>.all(<iterVar>, <predicate>)
    def self.rewrite_all(target, args)
      raise ParseError, "all() macro expects identifier as first argument" unless args[0].is_a?(AST::Identifier)
      raise ParseError, "#{args[0].name} is not a valid iteration var name" if args[0].name == ACCUMULATOR_NAME

      AST::Comprehension.new(
        iter_var: args[0].name,
        iter_range: target,
        accu_var: ACCUMULATOR_NAME,
        accu_init: AST::Literal.new(:bool, true),
        loop_condition: AST::Call.new(nil, "@not_strictly_false", [accu_ident]),
        loop_step: AST::Call.new(nil, "&&", [accu_ident, args[1]]),
        result: accu_ident
      )
    end

    def self.accu_ident
      AST::Identifier.new(ACCUMULATOR_NAME)
    end
  end
end

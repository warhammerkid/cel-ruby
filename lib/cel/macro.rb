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
      when "exists" then rewrite_exists(target, args)
      when "exists_one", "existsOne" then rewrite_exists_one(target, args)
      when "map" then rewrite_map(target, args)
      when "filter" then rewrite_filter(target, args)
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
      check_iter_var!("all()", args)

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

    # Expands the expression into a comprehension that returns true if any of
    # the elements in the range match the predicate expression:
    #
    #   <iterRange>.exists(<iterVar>, <predicate>)
    def self.rewrite_exists(target, args)
      check_iter_var!("exists()", args)

      AST::Comprehension.new(
        iter_var: args[0].name,
        iter_range: target,
        accu_var: ACCUMULATOR_NAME,
        accu_init: AST::Literal.new(:bool, false),
        loop_condition: AST::Literal.new(:bool, true),
        loop_step: AST::Call.new(nil, "||", [accu_ident, args[1]]),
        result: accu_ident
      )
    end

    # Expands the expression into a comprehension that returns true if exactly
    # one of the elements in the range match the predicate expression:
    #
    #   <iterRange>.existsOne(<iterVar>, <predicate>)
    def self.rewrite_exists_one(target, args)
      check_iter_var!("existsOne()", args)

      AST::Comprehension.new(
        iter_var: args[0].name,
        iter_range: target,
        accu_var: ACCUMULATOR_NAME,
        accu_init: AST::Literal.new(:int, 0),
        loop_condition: AST::Literal.new(:bool, true),
        loop_step: AST::Call.new(
          nil, "?:",
          [
            args[1],
            AST::Call.new(nil, "+", [accu_ident, AST::Literal.new(:int, 1)]),
            accu_ident,
          ]
        ),
        result: AST::Call.new(nil, "==", [accu_ident, AST::Literal.new(:int, 1)])
      )
    end

    # Expands the expression into a comprehension that transforms each element
    # in the input to produce an output list.
    #
    # There are two call patterns supported by map:
    #
    #   <iterRange>.map(<iterVar>, <transform>)
    #   <iterRange>.map(<iterVar>, <predicate>, <transform>)
    #
    # In the second form only iterVar values which return true when provided to
    # the predicate expression are transformed.
    def self.rewrite_map(target, args)
      check_iter_var!("map()", args)

      if args.size == 3
        filter = args[1]
        fn = args[2]
      else
        filter = nil
        fn = args[1]
      end

      step = AST::Call.new(nil, "+", [accu_ident, AST::CreateList.new([fn])])
      step = AST::Call.new(nil, "?:", [filter, step, accu_ident]) if filter

      AST::Comprehension.new(
        iter_var: args[0].name,
        iter_range: target,
        accu_var: ACCUMULATOR_NAME,
        accu_init: AST::CreateList.new([]),
        loop_condition: AST::Literal.new(:bool, true),
        loop_step: step,
        result: accu_ident
      )
    end

    # Expands the expression into a comprehension which produces a list which
    # contains only elements which match the provided predicate expression:
    #
    #   <iterRange>.filter(<iterVar>, <predicate>)
    def self.rewrite_filter(target, args)
      check_iter_var!("filter()", args)

      step = AST::Call.new(nil, "+", [accu_ident, AST::CreateList.new([args[0]])])
      step = AST::Call.new(nil, "?:", [args[1], step, accu_ident])

      AST::Comprehension.new(
        iter_var: args[0].name,
        iter_range: target,
        accu_var: ACCUMULATOR_NAME,
        accu_init: AST::CreateList.new([]),
        loop_condition: AST::Literal.new(:bool, true),
        loop_step: step,
        result: accu_ident
      )
    end

    def self.accu_ident
      AST::Identifier.new(ACCUMULATOR_NAME)
    end

    def self.check_iter_var!(macro, args)
      raise ParseError, "#{macro} macro expects identifier as first argument" unless args[0].is_a?(AST::Identifier)
      raise ParseError, "#{args[0].name} is not a valid iteration var name" if args[0].name == ACCUMULATOR_NAME
    end
  end
end

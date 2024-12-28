# frozen_string_literal: true

module Cel
  # This module takes an AST direct from the RACC parser and performs various
  # optimizations, both for correctness and performance
  module AstOptimizer
    def self.optimize!(ast)
      ast = optimize_negative_numbers!(ast)
      ast = optimize_nested_unary!(ast)
      remove_nested_nodes!(ast)
    end

    # Unary negatives should be directly applied to numbers, per the spec, which
    # we need to do here because we can't do them as part of parsing
    def self.optimize_negative_numbers!(ast)
      new_ast = modify_tree!(ast) do |node|
        next nil unless node.is_a?(AST::Call)
        next nil unless node.function == "-"
        next nil unless node.args.size == 1

        first_arg = node.args[0]
        next nil unless first_arg.is_a?(AST::Literal)
        next nil unless first_arg.type == :int || first_arg.type == :double

        AST::Literal.new(first_arg.type, -first_arg.value)
      end
      new_ast || ast
    end

    # Nested unary calls should be combined
    def self.optimize_nested_unary!(ast)
      new_ast = modify_tree!(ast) do |node|
        next nil unless node.is_a?(AST::Call)
        next nil unless node.args.size == 1
        next nil unless node.function == "-" || node.function == "!"

        first_arg = node.args[0]
        next nil unless first_arg.is_a?(AST::Call)
        next nil unless first_arg.args.size == 1
        next nil unless first_arg.function == node.function

        first_arg.args[0]
      end
      new_ast || ast
    end

    # Remove unnecessary Nested nodes, now that we no longer need them to stop
    # over-optimizing unary calls
    def self.remove_nested_nodes!(ast)
      new_ast = modify_tree!(ast) do |node|
        next nil unless node.is_a?(AST::Nested)

        node.expr
      end
      new_ast || ast
    end

    def self.modify_tree!(ast, &block)
      # Modify node until it no longer is modified
      modified = false
      while (replacement = yield(ast))
        modified = true
        ast = replacement
      end

      # Walk children
      case ast
      when AST::Nested
        expr = modify_tree!(ast.expr, &block)
        ast.expr = expr if expr
      when AST::Select
        operand = modify_tree!(ast.operand, &block)
        ast.operand = operand if operand
      when AST::Call
        if ast.target
          target = modify_tree!(ast.target, &block)
          ast.target = target if target
        end
        ast.args.each_with_index do |arg, i|
          arg = modify_tree!(arg, &block)
          ast.args[i] = arg if arg
        end
      when AST::CreateList
        ast.elements.each_with_index do |element, i|
          element = modify_tree!(element, &block)
          ast.elements[i] = element if element
        end
      when AST::CreateStruct
        ast.entries.each_with_index do |entry, i|
          entry = modify_tree!(entry, &block)
          ast.entries[i] = entry if entry
        end
      when AST::Entry
        if ast.key.is_a?(AST::Expr)
          key = modify_tree!(ast.key, &block)
          ast.key = key if key
        end

        value = modify_tree!(ast.value, &block)
        ast.value = value if value
      when AST::Comprehension
        iter_range = modify_tree!(ast.iter_range, &block)
        ast.iter_range = iter_range if iter_range

        accu_init = modify_tree!(ast.accu_init, &block)
        ast.accu_init = accu_init if accu_init

        loop_condition = modify_tree!(ast.loop_condition, &block)
        ast.loop_condition = loop_condition if loop_condition

        loop_step = modify_tree!(ast.loop_step, &block)
        ast.loop_step = loop_step if loop_step

        result = modify_tree!(ast.result, &block)
        ast.result = result if result
      when AST::Literal, AST::Identifier
        # Do nothing
      else
        raise "Unexpected node: #{ast.inspect}"
      end

      modified ? ast : nil
    end
  end
end

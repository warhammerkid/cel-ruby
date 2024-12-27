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

    def self.modify_tree!(ast, &)
      replacement = yield(ast)
      ast = replacement if replacement

      case ast
      when AST::Nested
        expr = modify_tree!(ast.expr, &)
        ast.expr = expr unless expr.nil?
      when AST::Select
        operand = modify_tree!(ast.operand, &)
        ast.operand = operand unless operand.nil?
      when AST::Call
        if ast.target
          target = modify_tree!(ast.target, &)
          ast.target = target unless target.nil?
        end
        ast.args.each_with_index do |arg, i|
          arg = modify_tree!(arg, &)
          ast.args[i] = arg unless arg.nil?
        end
      when AST::CreateList
        ast.elements.each_with_index do |element, i|
          element = modify_tree!(element, &)
          ast.elements[i] = element unless element.nil?
        end
      when AST::CreateStruct
        ast.entries.each_with_index do |entry, i|
          entry = modify_tree!(entry, &)
          ast.entries[i] = entry unless entry.nil?
        end
      when AST::Entry
        if ast.key.is_a?(AST::Expr)
          key = modify_tree!(ast.key, &)
          ast.key = key unless key.nil?
        end

        value = modify_tree!(ast.value, &)
        ast.value = value unless value.nil?
      when AST::Literal, AST::Identifier, AST::Comprehension
        # Do nothing
      else
        raise "Unexpected node: #{ast.inspect}"
      end

      replacement
    end
  end
end

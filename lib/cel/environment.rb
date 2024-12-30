# frozen_string_literal: true

module Cel
  class Environment
    attr_reader :declarations

    def initialize(declarations = nil)
      @declarations = declarations
      @parser = Parser.new
    end

    # Parses the given expression and returns the AST
    def parse(expr)
      @parser.parse(expr)
    end

    # Checks the given AST for correctness and returns the AST
    def check(ast)
      ast # Checking is not implemented yet
    end

    # Parses and checks the given expression and returns the AST
    def compile(expr)
      ast = @parser.parse(expr)
      check(ast)
    end

    # Creates a runner for the given AST
    def program(ast)
      ast = @parser.parse(ast) if ast.is_a?(::String)
      Runner.new(self, ast)
    end

    # Parses, checks, and evaluates the given expression with the given bindings
    def evaluate(expr, bindings = nil)
      expr = @parser.parse(expr) if expr.is_a?(::String)
      check(expr)
      Runner.new(self, expr).evaluate(bindings)
    end
  end

  class Runner
    def initialize(environment, ast)
      @environment = environment
      @ast = ast
    end

    def evaluate(bindings = nil)
      context = Context.new(@environment.declarations, bindings)
      Program.new(context).evaluate(@ast)
    end
  end
end

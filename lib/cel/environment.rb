# frozen_string_literal: true

module Cel
  class Environment
    def initialize(declarations = nil)
      @declarations = declarations
      @parser = Parser.new
      @checker = Checker.new(@declarations)
    end

    def compile(expr)
      ast = @parser.parse(expr)
      @checker.check(ast)
      ast
    end

    def check(expr)
      ast = @parser.parse(expr)
      @checker.check(ast)
    end

    def program(expr)
      expr = compile(expr) if expr.is_a?(::String)
      Runner.new(@declarations, expr)
    end

    def evaluate(expr, bindings = nil)
      context = Context.new(@declarations, bindings)
      expr = compile(expr) if expr.is_a?(::String)
      Program.new(context).evaluate(expr)
    end

    private

    def validate(ast, structs); end
  end

  class Runner
    def initialize(declarations, ast)
      @declarations = declarations
      @ast = ast
    end

    def evaluate(bindings = nil)
      context = Context.new(@declarations, bindings)
      Program.new(context).evaluate(@ast)
    end
  end
end

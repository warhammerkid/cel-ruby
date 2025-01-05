# frozen_string_literal: true

module Cel
  class Environment
    def initialize(declarations = nil)
      @declarations = declarations
      @parser = Parser.new
    end

    def compile(expr)
      @parser.parse(expr)
    end

    def check(_expr)
      true
    end

    def program(expr)
      expr = @parser.parse(expr) if expr.is_a?(::String)
      Runner.new(@declarations, expr)
    end

    def evaluate(expr, bindings = nil)
      context = Context.new(@declarations, bindings)
      expr = @parser.parse(expr) if expr.is_a?(::String)
      Program.new(context).evaluate(expr)
    end
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

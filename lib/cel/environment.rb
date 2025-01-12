# frozen_string_literal: true

module Cel
  class Environment
    attr_reader :container, :declarations, :function_registry

    def initialize(declarations = nil, container = nil)
      @declarations = {}
      function_declarations = {}
      declarations&.each do |name, value|
        if value.is_a?(Cel::Function) || value.is_a?(Proc)
          function_declarations[name] = value
        else
          @declarations[name] = value
        end
      end

      @function_registry = FunctionRegistry.new(function_declarations)
      @function_registry.extend_functions(Cel::StandardFunctions)

      @container = container || DEFAULT_CONTAINER
      @parser = Parser.new
    end

    # Adds CEL functions defined in the given module to the function bindings
    # for the environment
    def extend_functions(mod)
      @function_registry.extend_functions(mod)
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
      context = Context.new(@environment.declarations, bindings, @environment.function_registry)
      Program.new(context, @environment.container).evaluate(@ast)
    end
  end
end

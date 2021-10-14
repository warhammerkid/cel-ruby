module Cel
  class Environment

    def initialize
      @parser = Parser.new
    end


    def validate(ast, structs)

    end


    def compile(expr)
      @parser.parse(expr)
    end

    def evaluate(expr, bindings = nil)
      context = Context.new(bindings)
      expr = compile(expr) if expr.is_a?(::String)
      Program.new(context).evaluate(expr)
    end
  end
end
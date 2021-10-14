module Cel
  class Environment

    def initialize(declarations=nil)
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

    def evaluate(expr, bindings = nil)
      context = Context.new(bindings)
      expr = compile(expr) if expr.is_a?(::String)
      Program.new(context).evaluate(expr)
    end

    private

    def validate(ast, structs)

    end
  end
end
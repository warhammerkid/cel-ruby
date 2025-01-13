# frozen_string_literal: true

require "cel/program/interpreter"
require "cel/program/comprehension"

module Cel
  class Program
    def self.plan(environment, ast)
      new(environment, ast)
    end

    def initialize(environment, ast)
      @environment = environment
      @ast = ast
    end

    def evaluate(bindings = nil)
      context = Context.new(@environment.declarations, bindings, @environment.function_registry)
      Interpreter.new(context, @environment.container).evaluate(@ast)
    end
  end
end

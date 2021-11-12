# frozen_string_literal: true

module Cel
  class Context
    def initialize(bindings)
      @bindings = bindings
    end

    def lookup(identifier)
      raise EvaluateError, "no value in context for #{identifier}" unless @bindings

      id = identifier.id
      val = @bindings.dig(*id.split(".").map(&:to_sym))

      raise EvaluateError, "no value in context for #{identifier}" unless val

      val
    end

    def merge(bindings)
      Context.new(@bindings ? @bindings.merge(bindings) : bindings)
    end
  end
end

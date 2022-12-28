# frozen_string_literal: true

module Cel
  class Context
    def initialize(declarations, bindings)
      @declarations = declarations
      @bindings = bindings.dup

      return unless @bindings

      @bindings.each do |k, v|
        val = to_cel_type(v)
        val = TYPES[@declarations[k]].cast(val) if @declarations && @declarations.key?(k)
        @bindings[k] = val
      end
    end

    def lookup(identifier)
      raise EvaluateError, "no value in context for #{identifier}" unless @bindings

      id = identifier.id
      val = @bindings.dig(*id.split(".").map(&:to_sym))

      raise EvaluateError, "no value in context for #{identifier}" unless val

      val
    end

    def merge(bindings)
      Context.new(@declarations, @bindings ? @bindings.merge(bindings) : bindings)
    end

    private

    def to_cel_type(v)
      Literal.to_cel_type(v)
    end
  end
end

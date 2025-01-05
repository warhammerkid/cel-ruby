# frozen_string_literal: true

module Cel
  class Context
    attr_reader :declarations

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
      # Check bindings first
      if @bindings
        id = identifier.id
        val = @bindings.dig(*id.split(".").map(&:to_sym))
        return val if val
      end

      # If protobufs are enabled, check protobuf environment for an enum
      return Cel::Protobuf.lookup_enum(identifier) if defined?(Cel::Protobuf) && identifier.id == "google"

      raise EvaluateError, "no value in context for #{identifier}"
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

# frozen_string_literal: true

module Cel
  class Context
    attr_reader :declarations

    def initialize(declarations, bindings, function_registry = nil)
      @declarations = declarations
      @bindings = bindings.dup
      @function_registry = function_registry

      return unless @bindings

      @bindings.each do |k, v|
        @bindings[k] = Cel.to_value(v)
      end
    end

    def lookup(identifier)
      # Check bindings first
      if @bindings
        val = @bindings.dig(*identifier.split(".").map(&:to_sym))
        return val if val
      end

      # If protobufs are enabled, check protobuf environment for an enum
      return Cel::Protobuf.lookup_enum(identifier) if defined?(Cel::Protobuf) && identifier == "google"

      raise EvaluateError, "no value in context for #{identifier}"
    end

    def lookup_function(call_ast, args)
      @function_registry.lookup_function(call_ast, args)
    end

    def merge(bindings)
      Context.new(@declarations, @bindings ? @bindings.merge(bindings) : bindings, @function_registry)
    end
  end
end

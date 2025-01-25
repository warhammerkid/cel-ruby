# frozen_string_literal: true

module Cel
  class Context
    attr_reader :declarations

    def initialize(declarations, bindings, function_registry = nil)
      @declarations = declarations
      @bindings = (bindings || {}).to_h { |k, v| [k.to_s, Cel.to_value(v)] }
      @function_registry = function_registry
    end

    def lookup(identifier)
      # Check bindings first
      return @bindings[identifier] if @bindings.key?(identifier)

      # If protobufs are enabled, check protobuf environment for an enum
      return Cel::Protobuf.lookup_enum(identifier) if defined?(Cel::Protobuf)

      nil
    end

    def lookup_function(call_ast, args)
      @function_registry.lookup_function(call_ast, args)
    end

    def merge(bindings)
      Context.new(@declarations, @bindings.merge(bindings), @function_registry)
    end
  end
end

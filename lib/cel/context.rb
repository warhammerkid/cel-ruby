module Cel
  class Context
    def initialize(bindings)
      @bindings = bindings
    end

    def lookup(identifier)
      raise Error.new("no value in context for #{identifier}") unless @bindings

      id = identifier.id
      val = @bindings.dig(*id.split(".").map(&:to_sym))

      raise Error.new("no value in context for #{identifier}") unless val

      val
    end
  end
end

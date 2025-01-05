# frozen_string_literal: true

module Cel
  # Container provides support for resolving qualified names for protobufs in
  # the CEL expression.
  class Container
    def initialize(name)
      raise ArgumentError, "name cannot start with '.'" if name.start_with?(".")

      @name = name
    end

    # Returns all potential fully qualified names for the given name in the
    # prefered resolution order. Based on ResolveCandidateNames from cel-go.
    def resolve(name)
      return [name[1..]] if name.start_with?(".")
      return [name] if @name == ""

      container = @name
      candidates = ["#{container}.#{name}"]
      while (i = container.rindex("."))
        container = container[0...i]
        candidates << "#{container}.#{name}"
      end
      candidates << name

      candidates
    end
  end

  DEFAULT_CONTAINER = Container.new("")
end

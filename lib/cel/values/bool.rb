# frozen_string_literal: true

module Cel
  class Bool < Value
    extend FunctionBindings

    attr_reader :value

    def initialize(value)
      super(TYPES[:bool])
      @value = value
    end

    def hash
      @value.hash
    end

    def ==(other)
      other.is_a?(Bool) && @value == other.value
    end
    alias_method :eql?, :==

    # Comparison method used to implement all other comparison methods. It is
    # called internally and expected to return a Ruby integer of -1, 0, or 1.
    def <=>(other)
      raise EvaluateError, "Unhandled comparison" unless other.is_a?(Bool)

      return 0 if @value == other.value

      !@value && other.value ? -1 : 1
    end

    def to_ruby
      @value
    end

    def cast_to_type(type)
      case type
      when TYPES[:string] then String.new(@value ? "true" : "false")
      else raise EvaluateError, "Could not cast bool to #{type}"
      end
    end

    cel_func { global_function("!", %i[bool], :bool) }
    def !
      Bool.new(!@value)
    end
  end
end

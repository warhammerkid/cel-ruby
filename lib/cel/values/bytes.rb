# frozen_string_literal: true

module Cel
  class Bytes < Value
    extend FunctionBindings

    attr_reader :value

    def initialize(value)
      super(TYPES[:bytes])
      @value = value
    end

    def ==(other)
      other.is_a?(Bytes) && @value == other.value
    end

    # Comparison method used to implement all other comparison methods. It is
    # called internally and expected to return a Ruby integer of -1, 0, or 1.
    def <=>(other)
      raise EvaluateError, "Unhandled comparison" unless other.is_a?(Bytes)

      @value <=> other.value
    end

    def to_ruby
      @value
    end

    def cast_to_type(type)
      case type
      when TYPES[:string]
        str = @value.dup.force_encoding("UTF-8")
        raise EvaluateError, "Invalid UTF-8" unless str.valid_encoding?

        String.new(str)
      else raise EvaluateError, "Could not cast bytes to #{type}"
      end
    end

    cel_func do
      global_function("size", %i[bytes], :int)
      receiver_function("size", :bytes, [], :int)
    end
    def size
      Number.new(:int, @value.size)
    end

    cel_func { global_function("+", %i[bytes bytes], :bytes) }
    def +(other)
      Bytes.new(@value + other.value)
    end
  end
end

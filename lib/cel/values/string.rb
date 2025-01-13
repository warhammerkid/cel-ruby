# frozen_string_literal: true

module Cel
  class String < Value
    TRUE_VALUE = %w[1 t T TRUE true True].freeze
    FALSE_VALUE = %w[0 f F FALSE false False].freeze

    extend FunctionBindings

    attr_reader :value

    def initialize(value)
      super(TYPES[:string])
      @value = value
    end

    def hash
      @value.hash
    end

    def ==(other)
      other.is_a?(String) && @value == other.value
    end
    alias_method :eql?, :==

    # Comparison method used to implement all other comparison methods. It is
    # called internally and expected to return a Ruby integer of -1, 0, or 1.
    def <=>(other)
      raise EvaluateError, "Unhandled comparison" unless other.is_a?(String)

      @value <=> other.value
    end

    def to_ruby
      @value
    end

    def cast_to_type(type)
      case type
      when TYPES[:bool]
        if TRUE_VALUE.include?(@value)
          Bool.new(true)
        elsif FALSE_VALUE.include?(@value)
          Bool.new(false)
        else
          raise EvaluateError, "Could not convert #{@value} to bool"
        end
      when TYPES[:bytes] then Bytes.new(@value.b)
      when TYPES[:double]
        Number.new(:double, @value == "NaN" ? Float::NAN : @value.to_f)
      when TYPES[:int] then Number.new(:int, @value.to_i)
      when TYPES[:uint]
        int = @value.to_i
        raise EvaluateError, "Out of range" if int.negative?

        Number.new(:uint, int)
      when TYPES[:duration] then Duration.parse(@value)
      when TYPES[:timestamp] then Timestamp.parse(@value)
      else raise EvaluateError, "Could not cast string to #{type}"
      end
    end

    cel_func do
      global_function("size", %i[string], :int)
      receiver_function("size", :string, [], :int)
    end
    def size
      Number.new(:int, @value.size)
    end

    cel_func { global_function("+", %i[string string], :string) }
    def +(other)
      String.new(@value + other.value)
    end

    cel_func { receiver_function("contains", :string, %i[string], :bool) }
    def contains(string)
      Bool.new(@value.include?(string.value))
    end

    cel_func { receiver_function("endsWith", :string, %i[string], :bool) }
    def ends_with(string)
      Bool.new(@value.end_with?(string.value))
    end

    cel_func { receiver_function("startsWith", :string, %i[string], :bool) }
    def starts_with(string)
      Bool.new(@value.start_with?(string.value))
    end

    cel_func do
      global_function("matches", %i[string string], :bool)
      receiver_function("matches", :string, %i[string], :bool)
    end
    def string_matches(pattern)
      pattern = Regexp.new(pattern.value)
      Bool.new(pattern.match?(@value))
    end
  end
end

# frozen_string_literal: true

module Cel
  class Duration < Value
    extend FunctionBindings

    attr_reader :value

    def self.parse(string)
      seconds = 0
      nanos = 0
      string.scan(/([0-9]*(?:\.[0-9]*)?)([a-z]+)/) do |duration, units|
        case units
        when "h"
          seconds += Cel.to_numeric(duration) * 60 * 60
        when "m"
          seconds += Cel.to_numeric(duration) * 60
        when "s"
          seconds += Cel.to_numeric(duration)
        when "ms"
          nanos += Cel.to_numeric(duration) * 1000 * 1000
        when "us"
          nanos += Cel.to_numeric(duration) * 1000
        when "ns"
          nanos += Cel.to_numeric(duration)
        else
          raise EvaluateError, "#{units} is unsupported"
        end
      end
      new(seconds + (nanos / 1_000_000_000.0))
    end

    def initialize(value)
      super(TYPES[:duration])
      @value = value
    end

    def ==(other)
      other.is_a?(Duration) && @value == other.value
    end

    # Comparison method used to implement all other comparison methods. It is
    # called internally and expected to return a Ruby integer of -1, 0, or 1.
    def <=>(other)
      raise EvaluateError, "Unhandled comparison" unless other.is_a?(Duration)

      @value <=> other.value
    end

    def to_ruby
      @value
    end

    def cast_to_type(type)
      case type
      when TYPES[:int] then Number.new(:int, @value.to_i)
      when TYPES[:string]
        parts = @value.divmod(1)
        Cel::String.new(parts.last.zero? ? "#{parts.first}s" : "#{@value}s")
      else raise EvaluateError, "Could not cast duration to #{type}"
      end
    end

    cel_func do
      global_function("+", %i[duration duration], :duration)
      global_function("+", %i[duration timestamp], :timestamp)
    end
    def +(other)
      case other
      when Duration
        Duration.new(@value + other.value)
      when Timestamp
        Timestamp.new(other.value + @value)
      end
    end

    cel_func do
      global_function("-", %i[duration duration], :duration)
    end
    def -(other)
      Duration.new(@value - other.value)
    end

    cel_func { receiver_function("getHours", :duration, [], :int) }
    def hours
      Number.new(:int, (@value / 3600).to_i)
    end

    cel_func { receiver_function("getMinutes", :duration, [], :int) }
    def minutes
      Number.new(:int, (@value / 60).to_i)
    end

    cel_func { receiver_function("getSeconds", :duration, [], :int) }
    def seconds
      Number.new(:int, @value.to_i)
    end

    cel_func { receiver_function("getMilliseconds", :duration, [], :int) }
    def milliseconds
      Number.new(:int, (@value * 1000).to_i % 1000)
    end
  end
end

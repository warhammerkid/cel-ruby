# frozen_string_literal: true

require "time"

module Cel
  class Timestamp < Value
    extend FunctionBindings

    attr_reader :value

    def self.parse(string)
      new(Time.parse(string))
    end

    def initialize(value)
      super(TYPES[:timestamp])
      @value = value
    end

    def ==(other)
      other.is_a?(Timestamp) && @value == other.value
    end

    # Comparison method used to implement all other comparison methods. It is
    # called internally and expected to return a Ruby integer of -1, 0, or 1.
    def <=>(other)
      raise EvaluateError, "Unhandled comparison" unless other.is_a?(Timestamp)

      @value <=> other.value
    end

    def to_ruby
      @value
    end

    def cast_to_type(type)
      case type
      when TYPES[:int] then Number.new(:int, @value.to_i)
      when TYPES[:string]
        if @value.nsec.zero?
          String.new(@value.strftime("%Y-%m-%dT%H:%M:%SZ"))
        else
          String.new(@value.strftime("%Y-%m-%dT%H:%M:%S.%9NZ"))
        end
      else raise EvaluateError, "Could not cast timestamp to #{type}"
      end
    end

    cel_func { global_function("+", %i[timestamp duration], :timestamp) }
    def +(other)
      Timestamp.new(@value + other.value)
    end

    cel_func do
      global_function("-", %i[timestamp timestamp], :duration)
      global_function("-", %i[timestamp duration], :timestamp)
    end
    def -(other)
      case other
      when Timestamp
        Duration.new(@value - other.value)
      when Duration
        Timestamp.new(@value - other.value)
      end
    end

    cel_func do
      receiver_function("getDate", :timestamp, [], :int)
      receiver_function("getDate", :timestamp, %i[string], :int)
    end
    def date(tz = nil)
      Number.new(:int, to_local_time(tz).day)
    end

    cel_func do
      receiver_function("getDayOfMonth", :timestamp, [], :int)
      receiver_function("getDayOfMonth", :timestamp, %i[string], :int)
    end
    def day_of_month(tz = nil)
      Number.new(:int, to_local_time(tz).day - 1)
    end

    cel_func do
      receiver_function("getDayOfWeek", :timestamp, [], :int)
      receiver_function("getDayOfWeek", :timestamp, %i[string], :int)
    end
    def day_of_week(tz = nil)
      Number.new(:int, to_local_time(tz).wday)
    end

    cel_func do
      receiver_function("getDayOfYear", :timestamp, [], :int)
      receiver_function("getDayOfYear", :timestamp, %i[string], :int)
    end
    def day_of_year(tz = nil)
      Number.new(:int, to_local_time(tz).yday - 1)
    end

    cel_func do
      receiver_function("getMonth", :timestamp, [], :int)
      receiver_function("getMonth", :timestamp, %i[string], :int)
    end
    def month(tz = nil)
      Number.new(:int, to_local_time(tz).month - 1)
    end

    cel_func do
      receiver_function("getFullYear", :timestamp, [], :int)
      receiver_function("getFullYear", :timestamp, %i[string], :int)
    end
    def full_year(tz = nil)
      Number.new(:int, to_local_time(tz).year)
    end

    cel_func do
      receiver_function("getHours", :timestamp, [], :int)
      receiver_function("getHours", :timestamp, %i[string], :int)
    end
    def hours(tz = nil)
      Number.new(:int, to_local_time(tz).hour)
    end

    cel_func do
      receiver_function("getMinutes", :timestamp, [], :int)
      receiver_function("getMinutes", :timestamp, %i[string], :int)
    end
    def minutes(tz = nil)
      Number.new(:int, to_local_time(tz).min)
    end

    cel_func do
      receiver_function("getSeconds", :timestamp, [], :int)
      receiver_function("getSeconds", :timestamp, %i[string], :int)
    end
    def seconds(tz = nil)
      Number.new(:int, to_local_time(tz).sec)
    end

    cel_func do
      receiver_function("getMilliseconds", :timestamp, [], :int)
      receiver_function("getMilliseconds", :timestamp, %i[string], :int)
    end
    def milliseconds(tz = nil)
      Number.new(:int, to_local_time(tz).nsec / 1_000_000)
    end

    private

    def to_local_time(tz = nil)
      time = @value
      if tz
        tz = tz.value # Unwrap Cel::String
        tz = TZInfo::Timezone.get(tz) unless tz.match?(/\A[+-]\d{2,}:\d{2,}\z/)
        time = time.getlocal(tz)
      end
      time
    end
  end
end

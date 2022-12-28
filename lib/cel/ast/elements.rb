# frozen_string_literal: true

require "time"
require "delegate"
require_relative "elements/protobuf"

module Cel
  LOGICAL_OPERATORS = %w[< <= >= > == != in].freeze
  MULTI_OPERATORS = %w[* / %].freeze

  class Identifier < SimpleDelegator
    attr_reader :id

    attr_accessor :type

    def initialize(identifier)
      @id = identifier
      @type = TYPES[:any]
      super(@id)
    end

    def ==(other)
      super || other.to_s == @id.to_s
    end

    def to_s
      @id.to_s
    end
  end

  class Message < SimpleDelegator
    attr_reader :type, :struct

    def self.new(type, struct)
      value = convert_from_type(type, struct)
      return value if value.is_a?(Null) || value != struct

      super
    end

    def initialize(type, struct)
      @struct = Struct.new(*struct.keys.map(&:to_sym)).new(*struct.values)
      @type = type.is_a?(Type) ? type : MapType.new(struct.to_h do |k, v|
                                                      [Literal.to_cel_type(k), Literal.to_cel_type(v)]
                                                    end)
      super(@struct)
    end

    def field?(key)
      !@type.get(key).nil?
    end

    def self.convert_from_type(type, value)
      case type
      when Invoke, Identifier
        spread_type = type.to_s
        Protobuf.convert_from_type(spread_type, value)
      when Type
        [type, value]
      else
        [
          MapType.new(struct.to_h do |k, v|
            [Literal.to_cel_type(k), Literal.to_cel_type(v)]
          end),
          Struct.new(*struct.keys.map(&:to_sym)).new(*struct.values),
        ]
      end
    end
  end

  class Invoke
    attr_reader :var, :func, :args

    def self.new(func:, var: nil, args: nil)
      Protobuf.try_invoke_from(var, func, args) || super
    end

    def initialize(func:, var: nil, args: nil)
      @var = var
      @func = func.to_sym
      @args = args
    end

    def ==(other)
      super || (
        other.respond_to?(:to_ary) &&
        [@var, @func, @args].compact == other
      )
    end

    def to_s
      if var
        if func == :[]
          "#{var}[#{args}]"
        else
          "#{var}.#{func}#{"(#{args.map(&:to_s).join(", ")})" if args}"
        end
      else
        "#{func}#{"(#{args.map(&:to_s).join(", ")})" if args}"
      end
    end
  end

  class Literal < SimpleDelegator
    attr_reader :type, :value

    def initialize(type, value)
      @type = type.is_a?(Type) ? type : TYPES[type]
      @value = value
      super(value)
      check
    end

    def ==(other)
      @value == other || super
    end

    def self.to_cel_type(val)
      val = Protobuf.convert_from_protobuf(val) if val.is_a?(Google::Protobuf::MessageExts)

      case val
      when Literal, Identifier
        val
        # TODO: should support byte streams?
      when ::String
        String.new(val)
      when ::Symbol
        Identifier.new(val)
      when ::Integer
        Number.new(:int, val)
      when ::Float, ::BigDecimal
        Number.new(:double, val)
      when ::Hash
        Map.new(val)
      when ::Array
        List.new(val)
      when true, false
        Bool.new(val)
      when nil
        Null.new
      when Time
        Timestamp.new(val)
      else
        raise BindingError, "can't convert #{val} to CEL type"
      end
    end

    private

    def check; end
  end

  class Number < Literal
    [:+, :-, *MULTI_OPERATORS].each do |op|
      class_eval(<<-OUT, __FILE__, __LINE__ + 1)
        def #{op}(other)
          Number.new(@type, super)
        end
      OUT
    end

    LOGICAL_OPERATORS.each do |op|
      class_eval(<<-OUT, __FILE__, __LINE__ + 1)
        def #{op}(other)
          Bool.new(super)
        end
      OUT
    end
  end

  class Bool < Literal
    def initialize(value)
      super(:bool, value)
    end

    LOGICAL_OPERATORS.each do |op|
      class_eval(<<-OUT, __FILE__, __LINE__ + 1)
        def #{op}(other)
          Bool.new(super)
        end
      OUT
    end
  end

  class Null < Literal
    def initialize
      super(:null_type, nil)
    end
  end

  class String < Literal
    def initialize(value)
      super(:string, value)
    end

    # CEL string functions

    def contains(string)
      Bool.new(@value.include?(string))
    end

    def endsWith(string)
      Bool.new(@value.end_with?(string))
    end

    def startsWith(string)
      Bool.new(@value.start_with?(string))
    end

    def matches(pattern)
      Macro.matches(self, pattern)
    end

    LOGICAL_OPERATORS.each do |op|
      class_eval(<<-OUT, __FILE__, __LINE__ + 1)
        def #{op}(other)
          other.is_a?(Cel::Literal) ? Bool.new(super) : super
        end
      OUT
    end

    %i[+ -].each do |op|
      class_eval(<<-OUT, __FILE__, __LINE__ + 1)
        def #{op}(other)
          String.new(super)
        end
      OUT
    end
  end

  class Bytes < Literal
    def initialize(value)
      super(:bytes, value)
    end

    def to_ary
      [self]
    end

    LOGICAL_OPERATORS.each do |op|
      class_eval(<<-OUT, __FILE__, __LINE__ + 1)
        def #{op}(other)
          Bool.new(super)
        end
      OUT
    end

    %i[+ -].each do |op|
      class_eval(<<-OUT, __FILE__, __LINE__ + 1)
        def #{op}(other)
          String.new(@type, super)
        end
      OUT
    end
  end

  class List < Literal
    def initialize(value)
      value = value.map do |v|
        Literal.to_cel_type(v)
      end
      super(ListType.new(value), value)
    end

    def to_ary
      [self]
    end
  end

  class Map < Literal
    def initialize(value)
      value = value.to_h do |k, v|
        [Literal.to_cel_type(k), Literal.to_cel_type(v)]
      end
      super(MapType.new(value), value)
      check
    end

    def ==(other)
      super || (
        other.respond_to?(:to_hash) &&
        @value.zip(other).all? { |(x1, y1), (x2, y2)| x1 == x2 && y1 == y2 }
      )
    end

    def to_ary
      [self]
    end

    def respond_to_missing?(meth, *args)
      super || (@value && @value.keys.any? { |k| k.to_s == meth.to_s })
    end

    def method_missing(meth, *args)
      return super unless @value

      key = @value.keys.find { |k| k.to_s == meth.to_s } or return super

      @value[key]
    end

    private

    ALLOWED_TYPES = %i[int uint bool string].map { |typ| TYPES[typ] }.freeze

    # For a map, the entry keys are sub-expressions that must evaluate to values
    # of an allowed type (int, uint, bool, or string)
    def check
      return if @value.each_key.all? { |key| key.is_a?(Identifier) || ALLOWED_TYPES.include?(key.type) }

      raise CheckError, "#{self} is invalid (keys must be of an allowed type (int, uint, bool, or string)"
    end
  end

  class Timestamp < Literal
    def initialize(value)
      value = case value
              when String then Time.parse(value)
              when Numeric then Time.at(value)
              else value
      end
      super(:timestamp, value)
    end

    def +(other)
      Timestamp.new(@value + other.to_f)
    end

    def -(other)
      case other
      when Timestamp
        Duration.new(@value - other.value)
      when Duration
        Timestamp.new(@value - other.to_f)
      end
    end

    LOGICAL_OPERATORS.each do |op|
      class_eval(<<-OUT, __FILE__, __LINE__ + 1)
        def #{op}(other)
          other.is_a?(Cel::Literal) ? Bool.new(super) : super
        end
      OUT
    end

    # Cel Functions

    def getDate(tz = nil)
      to_local_time(tz).day
    end

    def getDayOfMonth(tz = nil)
      getDate(tz) - 1
    end

    def getDayOfWeek(tz = nil)
      to_local_time(tz).wday
    end

    def getDayOfYear(tz = nil)
      to_local_time(tz).yday - 1
    end

    def getMonth(tz = nil)
      to_local_time(tz).month - 1
    end

    def getFullYear(tz = nil)
      to_local_time(tz).year
    end

    def getHours(tz = nil)
      to_local_time(tz).hour
    end

    def getMinutes(tz = nil)
      to_local_time(tz).min
    end

    def getSeconds(tz = nil)
      to_local_time(tz).sec
    end

    def getMilliseconds(tz = nil)
      to_local_time(tz).nsec / 1_000_000
    end

    private

    def to_local_time(tz = nil)
      time = @value
      if tz
        tz = TZInfo::Timezone.get(tz) unless tz.match?(/\A[+-]\d{2,}:\d{2,}\z/)
        time = time.getlocal(tz)
      end
      time
    end
  end

  class Duration < Literal
    def initialize(value)
      value = case value
              when String
                init_from_string(value)
              when Hash
                seconds, nanos = value.values_at(:seconds, :nanos)
                seconds ||= 0
                nanos ||= 0
                seconds + (nanos / 1_000_000_000.0)
              else
                value
      end
      super(:duration, value)
    end

    LOGICAL_OPERATORS.each do |op|
      class_eval(<<-OUT, __FILE__, __LINE__ + 1)
        def #{op}(other)
          case other
          when Cel::Literal
            Bool.new(super)
          when Numeric
            @value == other

          else
            super
          end
        end
      OUT
    end

    # Cel Functions

    def getHours
      (getMinutes / 60).to_i
    end

    def getMinutes
      (getSeconds / 60).to_i
    end

    def getSeconds
      @value.divmod(1).first
    end

    def getMilliseconds
      (@value.divmod(1).last * 1000).round
    end

    private

    def init_from_string(value)
      seconds = 0
      nanos = 0
      value.scan(/([0-9]*(?:\.[0-9]*)?)([a-z]+)/) do |duration, units|
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
      seconds + (nanos / 1_000_000_000.0)
    end
  end

  class Group
    attr_reader :value

    def initialize(value)
      @value = value
    end
  end

  class Operation
    attr_reader :op, :operands

    attr_accessor :type

    def initialize(op, operands)
      @op = op
      @operands = operands
      @type = TYPES[:any]
    end

    def ==(other)
      if other.is_a?(Array)
        other.size == @operands.size + 1 &&
          other.first == @op &&
          other.slice(1..-1).zip(@operands).all? { |x1, x2| x1 == x2 }
      else
        super
      end
    end

    def to_s
      return "#{@op}#{@operands.first}" if @operands.size == 1

      @operands.join(" #{@op} ")
    end
  end

  class Condition
    attr_reader :if, :then, :else

    def initialize(if_, then_, else_)
      @if = if_
      @then = then_
      @else = else_
    end
  end
end

# frozen_string_literal: true

require "time"
require "delegate"

module Cel
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

  class Invoke
    attr_reader :var, :func, :args

    def initialize(func:, var: nil, args: nil)
      @var = var
      @func = func.to_sym
      @args = args
    end

    def ==(other)
      case other
      when Invoke
        @var == other.var && @func == other.func && @args == other.args
      when Array
        [@var, @func, @args].compact == other
      else
        super
      end
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

  class Function
    attr_reader :types, :type

    def initialize(*types, return_type: nil, &func)
      unless func.nil?
        types = Array.new(func.arity) { TYPES[:any] } if types.empty?
        raise(Error, "number of arg types does not match number of yielded args") unless types.size == func.arity
      end
      @types = types.map { |typ| typ.is_a?(Type) ? typ : TYPES[typ] }
      @type = if return_type.nil?
        TYPES[:any]
      else
        return_type.is_a?(Type) ? return_type : TYPES[return_type]
      end
      @func = func
    end

    def call(*args)
      Literal.to_cel_type(@func.call(*args.map(&:to_ruby_type)))
    end
  end

  mod = self
  mod.define_singleton_method(:Function) do |*args, **kwargs, &blk|
    mod::Function.new(*args, **kwargs, &blk)
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
      other = other.value if other.is_a?(Literal)
      @value == other || super
    end

    def self.to_cel_type(val)
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

    def to_ruby_type
      @value
    end

    private

    def check; end
  end

  class Number < Literal
    extend FunctionBindings

    %w[+ - * /].each do |op|
      class_eval(<<-OUT, __FILE__, __LINE__ + 1)
        cel_func do
          global_function("#{op}", %i[double double], :double)
          global_function("#{op}", %i[int int], :int)
          global_function("#{op}", %i[uint uint], :uint)
        end
        def #{op}(other)
          Number.new(@type, super)
        end
      OUT
    end

    # Comparison method used to implement all other comparison methods. It is
    # called internally and expected to return a Ruby integer of -1, 0, or 1.
    def <=>(other)
      raise EvaluateError, "Unhandled comparison" unless other.is_a?(Number)

      @value <=> other.value
    end

    cel_func do
      global_function("-", %i[double], :double)
      global_function("-", %i[int], :int)
    end
    def unary_negate
      Number.new(@type, -@value)
    end

    cel_func do
      global_function("%", %i[int int], :int)
      global_function("%", %i[uint uint], :uint)
    end
    def remainder(other)
      Number.new(@type, @value.remainder(other.value))
    end
  end

  class Bool < Literal
    extend FunctionBindings

    def initialize(value)
      super(:bool, value)
    end

    # Comparison method used to implement all other comparison methods. It is
    # called internally and expected to return a Ruby integer of -1, 0, or 1.
    def <=>(other)
      raise EvaluateError, "Unhandled comparison" unless other.is_a?(Bool)

      return 0 if @value == other.value

      !@value && other.value ? -1 : 1
    end

    cel_func { global_function("!", %i[bool], :bool) }
    def !
      Bool.new(super)
    end
  end

  class Null < Literal
    def initialize
      super(:null_type, nil)
    end
  end

  class String < Literal
    extend FunctionBindings

    def initialize(value)
      super(:string, value)
    end

    # Comparison method used to implement all other comparison methods. It is
    # called internally and expected to return a Ruby integer of -1, 0, or 1.
    def <=>(other)
      raise EvaluateError, "Unhandled comparison" unless other.is_a?(String)

      @value <=> other.value
    end

    cel_func do
      global_function("size", %i[string], :int)
      receiver_function("size", :string, [], :int)
    end
    def size
      Number.new(:int, @value.size)
    end

    cel_func { receiver_function("contains", :string, %i[string], :bool) }
    def contains(string)
      Bool.new(@value.include?(string))
    end

    cel_func { receiver_function("endsWith", :string, %i[string], :bool) }
    def endsWith(string)
      Bool.new(@value.end_with?(string))
    end

    cel_func { receiver_function("startsWith", :string, %i[string], :bool) }
    def startsWith(string)
      Bool.new(@value.start_with?(string))
    end

    cel_func { global_function("+", %i[string string], :string) }
    def +(other)
      String.new(@value + other.value)
    end

    cel_func do
      global_function("matches", %i[string string], :bool)
      receiver_function("matches", :string, %i[string], :bool)
    end
    def string_matches(pattern)
      pattern = Regexp.new(pattern)
      Bool.new(pattern.match?(@value))
    end
  end

  class Bytes < Literal
    extend FunctionBindings

    def initialize(value)
      super(:bytes, value)
    end

    def to_ary
      [self]
    end

    # Comparison method used to implement all other comparison methods. It is
    # called internally and expected to return a Ruby integer of -1, 0, or 1.
    def <=>(other)
      raise EvaluateError, "Unhandled comparison" unless other.is_a?(Bytes)

      @value <=> other.value
    end

    cel_func { global_function("+", %i[bytes bytes], :bytes) }
    def +(other)
      Bytes.new(@value + other.value)
    end

    cel_func do
      global_function("size", %i[bytes], :int)
      receiver_function("size", :bytes, [], :int)
    end
    def size
      Number.new(:int, @value.size)
    end
  end

  class List < Literal
    extend FunctionBindings

    def initialize(value)
      value = value.map do |v|
        Literal.to_cel_type(v)
      end
      super(ListType.new(value), value)
    end

    def to_ary
      [self]
    end

    def to_ruby_type
      value.map(&:to_ruby_type)
    end

    cel_func { global_function("+", %i[list list], :list) }
    def +(other)
      raise EvaluateError, "Cannot append non-list" unless other.is_a?(List)

      List.new(@value + other.value)
    end

    cel_func { global_function("[]", %i[list int], :any) }
    def [](index)
      raise EvaluateError, "Index out of bounds" if index.value.negative?

      @value.fetch(index.value)
    end

    cel_func do
      global_function("size", %i[list], :int)
      receiver_function("size", :list, [], :int)
    end
    def size
      Number.new(:int, @value.size)
    end
  end

  class Map < Literal
    extend FunctionBindings

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

    cel_func { global_function("[]", %i[map any], :any) }
    def [](index)
      @value.fetch(index)
    end

    cel_func do
      global_function("size", %i[map], :int)
      receiver_function("size", :map, [], :int)
    end
    def size
      Number.new(:int, @value.size)
    end

    def to_ruby_type
      value.to_h { |*args| args.map(&:to_ruby_type) }
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
    extend FunctionBindings

    def initialize(value)
      value = case value
              when ::String then Time.parse(value)
              when Numeric then Time.at(value)
              else value
      end
      super(:timestamp, value)
    end

    # Comparison method used to implement all other comparison methods. It is
    # called internally and expected to return a Ruby integer of -1, 0, or 1.
    def <=>(other)
      # TODO: Remove this once the tests don't try to directly compare times
      # to wrapped Cel::Timestamp values
      return @value <=> other if other.is_a?(Time)

      raise EvaluateError, "Unhandled comparison" unless other.is_a?(Timestamp)

      @value <=> other.value
    end

    cel_func { global_function("+", %i[timestamp duration], :timestamp) }
    def +(other)
      Timestamp.new(@value + other.to_f)
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
        Timestamp.new(@value - other.to_f)
      end
    end

    # Cel Functions

    cel_func do
      receiver_function("getDate", :timestamp, [], :int)
      receiver_function("getDate", :timestamp, %i[string], :int)
    end
    def getDate(tz = nil)
      Number.new(:int, to_local_time(tz).day)
    end

    cel_func do
      receiver_function("getDayOfMonth", :timestamp, [], :int)
      receiver_function("getDayOfMonth", :timestamp, %i[string], :int)
    end
    def getDayOfMonth(tz = nil)
      getDate(tz) - 1
    end

    cel_func do
      receiver_function("getDayOfWeek", :timestamp, [], :int)
      receiver_function("getDayOfWeek", :timestamp, %i[string], :int)
    end
    def getDayOfWeek(tz = nil)
      Number.new(:int, to_local_time(tz).wday)
    end

    cel_func do
      receiver_function("getDayOfYear", :timestamp, [], :int)
      receiver_function("getDayOfYear", :timestamp, %i[string], :int)
    end
    def getDayOfYear(tz = nil)
      Number.new(:int, to_local_time(tz).yday - 1)
    end

    cel_func do
      receiver_function("getMonth", :timestamp, [], :int)
      receiver_function("getMonth", :timestamp, %i[string], :int)
    end
    def getMonth(tz = nil)
      Number.new(:int, to_local_time(tz).month - 1)
    end

    cel_func do
      receiver_function("getFullYear", :timestamp, [], :int)
      receiver_function("getFullYear", :timestamp, %i[string], :int)
    end
    def getFullYear(tz = nil)
      Number.new(:int, to_local_time(tz).year)
    end

    cel_func do
      receiver_function("getHours", :timestamp, [], :int)
      receiver_function("getHours", :timestamp, %i[string], :int)
    end
    def getHours(tz = nil)
      Number.new(:int, to_local_time(tz).hour)
    end

    cel_func do
      receiver_function("getMinutes", :timestamp, [], :int)
      receiver_function("getMinutes", :timestamp, %i[string], :int)
    end
    def getMinutes(tz = nil)
      Number.new(:int, to_local_time(tz).min)
    end

    cel_func do
      receiver_function("getSeconds", :timestamp, [], :int)
      receiver_function("getSeconds", :timestamp, %i[string], :int)
    end
    def getSeconds(tz = nil)
      Number.new(:int, to_local_time(tz).sec)
    end

    cel_func do
      receiver_function("getMilliseconds", :timestamp, [], :int)
      receiver_function("getMilliseconds", :timestamp, %i[string], :int)
    end
    def getMilliseconds(tz = nil)
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

  class Duration < Literal
    extend FunctionBindings

    def initialize(value)
      value = case value
              when ::String
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

    # Comparison method used to implement all other comparison methods. It is
    # called internally and expected to return a Ruby integer of -1, 0, or 1.
    def <=>(other)
      raise EvaluateError, "Unhandled comparison" unless other.is_a?(Duration)

      @value <=> other.value
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

    # Cel Functions

    cel_func { receiver_function("getHours", :duration, [], :int) }
    def getHours
      getMinutes / 60
    end

    cel_func { receiver_function("getMinutes", :duration, [], :int) }
    def getMinutes
      getSeconds / 60
    end

    cel_func { receiver_function("getSeconds", :duration, [], :int) }
    def getSeconds
      Number.new(:int, @value.divmod(1).first)
    end

    cel_func { receiver_function("getMilliseconds", :duration, [], :int) }
    def getMilliseconds
      Number.new(:int, (@value.divmod(1).last * 1000).round)
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

    def ==(other)
      other.is_a?(Group) && @value == other.value
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
      case other
      when Array
        other.size == @operands.size + 1 &&
          other.first == @op &&
          other.slice(1..-1).zip(@operands).all? { |x1, x2| x1 == x2 }
      when Operation
        @op == other.op && @type == other.type && @operands == other.operands
      else
        super
      end
    end

    def unary?
      @operands.size == 1
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

    def ==(other)
      other.is_a?(Condition) && @if == other.if && @then == other.then && @else == other.else
    end
  end
end

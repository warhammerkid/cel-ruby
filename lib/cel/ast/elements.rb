# frozen_string_literal: true

require "delegate"

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
  end

  class Message < SimpleDelegator
    attr_reader :type, :struct

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
  end

  class Invoke
    attr_reader :var, :func, :args

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

# frozen_string_literal: true

module Cel
  class Number < Value
    VALID_SUBTYPE = { double: true, int: true, uint: true }.freeze

    extend FunctionBindings

    attr_reader :value

    def initialize(subtype, value)
      real_subtype = subtype.is_a?(Type) ? subtype : TYPES.fetch(subtype)
      raise "Invalid subtype: #{subtype}" unless VALID_SUBTYPE.key?(real_subtype.to_sym)

      super(real_subtype)
      @value = value
    end

    def hash
      @value.hash
    end

    def ==(other)
      other.is_a?(Number) && @value == other.value
    end
    alias_method :eql?, :==

    # Comparison method used to implement all other comparison methods. It is
    # called internally and expected to return a Ruby integer of -1, 0, or 1.
    def <=>(other)
      raise EvaluateError, "Unhandled comparison" unless other.is_a?(Number)

      @value <=> other.value
    end

    def to_ruby
      @value
    end

    def cast_to_type(type)
      case type
      when TYPES[:double] then Number.new(:double, @value.to_f)
      when TYPES[:int] then Number.new(:int, @value.to_i)
      when TYPES[:uint]
        raise EvaluateError, "Out of range" if @value.negative?

        Number.new(:uint, @value.to_i)
      when TYPES[:string] then String.new(@value.to_s)
      when TYPES[:timestamp] then Timestamp.new(Time.at(@value))
      else raise EvaluateError, "Could not cast number to #{type}"
      end
    end

    %w[+ - * /].each do |op|
      class_eval(<<-OUT, __FILE__, __LINE__ + 1)
        cel_func do
          global_function("#{op}", %i[double double], :double)
          global_function("#{op}", %i[int int], :int)
          global_function("#{op}", %i[uint uint], :uint)
        end
        def #{op}(other)
          Number.new(@type, @value #{op} other.value)
        end
      OUT
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
end

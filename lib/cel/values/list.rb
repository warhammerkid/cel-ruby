# frozen_string_literal: true

module Cel
  class List < Value
    extend FunctionBindings

    attr_reader :value

    cel_func { global_function("in", %i[any list], :bool) }
    def self.in_collection(element, list)
      Cel::Bool.new(list.value.include?(element))
    end

    def initialize(value)
      super(TYPES[:list])
      @value = value
    end

    def ==(other)
      other.is_a?(List) && @value == other.value
    end

    def to_enum
      @value.each
    end

    def to_ruby
      @value.map(&:to_ruby)
    end

    cel_func do
      global_function("size", %i[list], :int)
      receiver_function("size", :list, [], :int)
    end
    def size
      Number.new(:int, @value.size)
    end

    cel_func { global_function("[]", %i[list int], :any) }
    def [](index)
      raise EvaluateError, "Index out of bounds" if index.value.negative?

      @value.fetch(index.value)
    end

    cel_func { global_function("+", %i[list list], :list) }
    def +(other)
      raise EvaluateError, "Cannot append non-list" unless other.is_a?(List)

      List.new(@value + other.value)
    end
  end
end

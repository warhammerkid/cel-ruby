# frozen_string_literal: true

module Cel
  class Map < Value
    extend FunctionBindings

    attr_reader :value

    cel_func { global_function("in", %i[any map], :bool) }
    def self.in_collection(element, map)
      Cel::Bool.new(map.value.include?(element))
    end

    def initialize(value)
      super(TYPES[:map])
      @value = value
      check
    end

    def ==(other)
      other.is_a?(Map) && @value == other.value
    end

    def to_enum
      @value.each_key
    end

    def to_ruby
      value.to_h { |*args| args.map(&:to_ruby) }
    end

    cel_func do
      global_function("size", %i[map], :int)
      receiver_function("size", :map, [], :int)
    end
    def size
      Number.new(:int, @value.size)
    end

    cel_func { global_function("[]", %i[map any], :any) }
    def [](index)
      @value.fetch(index)
    end

    # Used for test_only select
    def field_set?(key)
      Cel::Bool.new(@value.include?(Cel::String.new(key)))
    end

    private

    ALLOWED_TYPES = %i[int uint bool string].map { |typ| TYPES[typ] }.freeze

    # For a map, the entry keys are sub-expressions that must evaluate to values
    # of an allowed type (int, uint, bool, or string)
    def check
      return if @value.each_key.all? { |key| ALLOWED_TYPES.include?(key.type) }

      raise CheckError, "#{self} is invalid (keys must be of an allowed type (int, uint, bool, or string)"
    end
  end
end

# frozen_string_literal: true

module Cel
  module StandardFunctions
    class << self
      extend FunctionBindings

      #
      # Logical functions
      #

      cel_func { global_function("?:", %i[bool any any], :any) }
      def ternary_condition(condition, a, b)
        condition.value ? a : b
      end

      cel_func { global_function("&&", %i[bool bool], :bool) }
      def logical_and(a, b)
        Cel::Bool.new(a.value == true && b.value == true)
      end

      cel_func { global_function("||", %i[bool bool], :bool) }
      def logical_or(a, b)
        Cel::Bool.new(a.value == true || b.value == true)
      end

      #
      # Comprehension support functions
      #

      cel_func { global_function("@not_strictly_false", %i[any], :bool) }
      def not_strictly_false(value)
        value.is_a?(Cel::Bool) ? value : Cel::Bool.new(true)
      end

      #
      # Equality / Inequality functions
      #

      cel_func { global_function("==", %i[any any], :bool) }
      def is_equal(a, b) # rubocop:disable Naming/PredicateName
        Cel::Bool.new(a == b)
      end

      cel_func { global_function("!=", %i[any any], :bool) }
      def not_equal(a, b)
        Cel::Bool.new(!is_equal(a, b).value)
      end

      #
      # Comparison functions
      #

      [
        ["<", :less_than, ->(a, b) { Cel::Bool.new((a <=> b) == -1) }],
        ["<=", :less_than_equal, ->(a, b) { Cel::Bool.new((a <=> b) != 1) }],
        [">", :greater_than, ->(a, b) { Cel::Bool.new((a <=> b) == 1) }],
        [">=", :greater_than_equal, ->(a, b) { Cel::Bool.new((a <=> b) != -1) }],
      ].each do |operator, name, proc|
        cel_func do
          global_function(operator, %i[bool bool], :bool)
          global_function(operator, %i[bytes bytes], :bool)
          global_function(operator, %i[double double], :bool)
          global_function(operator, %i[double int], :bool)
          global_function(operator, %i[double uint], :bool)
          global_function(operator, %i[duration duration], :bool)
          global_function(operator, %i[int double], :bool)
          global_function(operator, %i[int int], :bool)
          global_function(operator, %i[int uint], :bool)
          global_function(operator, %i[string string], :bool)
          global_function(operator, %i[timestamp timestamp], :bool)
          global_function(operator, %i[uint double], :bool)
          global_function(operator, %i[uint int], :bool)
          global_function(operator, %i[uint uint], :bool)
        end
        define_method(name, &proc)
      end

      #
      # Collection functions
      #

      cel_func do
        global_function("in", %i[any list], :bool)
        global_function("in", %i[any map], :bool)
      end
      def in(element, collection)
        Cel::Bool.new(collection.include?(element))
      end

      #
      # Type conversion functions
      #

      cel_func do
        global_function("type", %i[any], :type)
      end
      def type(a)
        return a.type if a.respond_to?(:type)

        a.class
      end

      cel_func do
        global_function("bool", %i[bool], :bool)
        global_function("bytes", %i[bytes], :bytes)
        global_function("double", %i[double], :double)
        global_function("duration", %i[duration], :duration)
        global_function("dyn", %i[any], :any)
        global_function("int", %i[int], :int)
        global_function("string", %i[string], :string)
        global_function("timestamp", %i[timestamp], :timestamp)
        global_function("uint", %i[uint], :uint)
      end
      def cast_identity(a)
        a
      end

      cel_func { global_function("bool", %i[string], :bool) }
      def cast_to_bool(a)
        TYPES[:bool].cast(a)
      end

      cel_func { global_function("bytes", %i[string], :bytes) }
      def cast_to_bytes(a)
        TYPES[:bytes].cast(a)
      end

      cel_func do
        global_function("double", %i[int], :double)
        global_function("double", %i[string], :double)
        global_function("double", %i[uint], :double)
      end
      def cast_to_double(a)
        TYPES[:double].cast(a)
      end

      cel_func do
        global_function("duration", %i[int], :duration)
        global_function("duration", %i[string], :duration)
      end
      def cast_to_duration(a)
        TYPES[:duration].cast(a)
      end

      cel_func do
        global_function("int", %i[double], :int)
        global_function("int", %i[duration], :int)
        global_function("int", %i[string], :int)
        global_function("int", %i[timestamp], :int)
        global_function("int", %i[uint], :int)
      end
      def cast_to_int(a)
        TYPES[:int].cast(a)
      end

      cel_func do
        global_function("string", %i[bool], :string)
        global_function("string", %i[bytes], :string)
        global_function("string", %i[double], :string)
        global_function("string", %i[duration], :string)
        global_function("string", %i[int], :string)
        global_function("string", %i[timestamp], :string)
        global_function("string", %i[uint], :string)
      end
      def cast_to_string(a)
        TYPES[:string].cast(a)
      end

      cel_func do
        global_function("timestamp", %i[int], :timestamp)
        global_function("timestamp", %i[string], :timestamp)
      end
      def cast_to_timestamp(a)
        TYPES[:timestamp].cast(a)
      end

      cel_func do
        global_function("uint", %i[double], :uint)
        global_function("uint", %i[int], :uint)
        global_function("uint", %i[string], :uint)
      end
      def cast_to_uint(a)
        TYPES[:uint].cast(a)
      end
    end

    # Import additional bindings from value types
    value_types = [
      Cel::Bool,
      Cel::Bytes,
      Cel::Duration,
      Cel::List,
      Cel::Map,
      Cel::Number,
      Cel::String,
      Cel::Timestamp,
    ]
    value_types << Types::Message if defined?(Types::Message)
    value_types.each { |k| FunctionBindings.bindings(self).concat(FunctionBindings.bindings(k)) }
  end
end

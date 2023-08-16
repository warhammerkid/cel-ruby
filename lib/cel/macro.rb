# frozen_string_literal: true

module Cel
  module Macro
    module_function

    # If e evaluates to a protocol buffers version 2 message and f is a defined field:
    #     If f is a repeated field or map field, has(e.f) indicates whether the field is non-empty.
    #     If f is a singular or oneof field, has(e.f) indicates whether the field is set.
    # If e evaluates to a protocol buffers version 3 message and f is a defined field:
    #     If f is a repeated field or map field, has(e.f) indicates whether the field is non-empty.
    #     If f is a oneof or singular message field, has(e.f) indicates whether the field is set.
    #     If f is some other singular field, has(e.f) indicates whether the field's value is its default
    #       value (zero for numeric fields, false for booleans, empty for strings and bytes).
    def has(invoke)
      var = invoke.var
      func = invoke.func

      case var
      when Message
        # If e evaluates to a message and f is not a declared field for the message,
        # has(e.f) raises a no_such_field error.
        raise NoSuchFieldError.new(var, func) unless var.field?(func)

        Bool.new(!var.public_send(func).nil?)
      when Map
        # If e evaluates to a map, then has(e.f) indicates whether the string f
        # is a key in the map (note that f must syntactically be an identifier).
        Bool.new(var.respond_to?(func))
      else
        # In all other cases, has(e.f) evaluates to an error.
        raise EvaluateError, "#{invoke} is not supported"
      end
    end

    def size(literal)
      literal.size
    end

    def matches(string, pattern)
      pattern = Regexp.new(pattern)
      Bool.new(pattern.match?(string))
    end

    def all(collection, identifier, predicate, context:)
      return_value = collection.all? do |element, *|
        Program.new(context.merge(identifier.to_sym => element)).evaluate(predicate).value
      end
      Bool.new(return_value)
    end

    def exists(collection, identifier, predicate, context:)
      return_value = collection.any? do |element, *|
        Program.new(context.merge(identifier.to_sym => element)).evaluate(predicate).value
      end
      Bool.new(return_value)
    end

    def exists_one(collection, identifier, predicate, context:)
      return_value = collection.one? do |element, *|
        Program.new(context.merge(identifier.to_sym => element)).evaluate(predicate).value
      end
      Bool.new(return_value)
    end

    def filter(collection, identifier, predicate, context:)
      collection.select do |element, *|
        Program.new(context.merge(identifier.to_sym => element)).evaluate(predicate).value
      end
    end

    def map(collection, identifier, predicate, context:)
      collection.map do |element, *|
        Program.new(context.merge(identifier.to_sym => element)).evaluate(predicate)
      end
    end
  end
end

# frozen_string_literal: true

module Cel
  class Error < StandardError; end

  class ParseError < Error; end

  class CheckError < Error; end

  class EvaluateError < Error; end

  class NoSuchFieldError < EvaluateError
    attr_reader :code

    def initialize(var, attrib)
      super("No such field: #{var}.#{attrib}")
      @code = :no_such_field
    end
  end

  class NoMatchingOverloadError < CheckError
    attr_reader :code

    def initialize(op)
      super("No matching overload: #{op}")
      @code = :no_matching_overload
    end
  end
end

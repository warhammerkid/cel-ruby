module Cel
  class Error < StandardError; end
  class NoSuchFieldError < Error
    attr_reader :code

    def initialize(var, attrib)
      super("No such field: #{var}.#{attrib}")
      @code = :no_such_field
    end
  end

  class NoMatchingOverloadError < Error
    attr_reader :code

    def initialize(op)
      super("No matching overload: #{op}")
      @code = :no_matching_overload
    end
  end

end
module Cel
  class Error < StandardError; end
  class NoSuchFieldError < Error
    def initialize(var, attrib)
      super("No such field: #{var}.#{attrib}")
    end
  end

end
# frozen_string_literal: true

module Cel
  class Null < Value
    def initialize
      super(TYPES[:null_type])
    end

    def ==(other)
      other.is_a?(Null)
    end

    def to_ruby
      nil
    end
  end
end

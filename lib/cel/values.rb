# frozen_string_literal: true

module Cel
  # Converts the given ruby value to a Cel value
  def self.to_value(ruby_value)
    case ruby_value
    when Value then ruby_value
    when ::String then String.new(ruby_value)
    when Symbol then String.new(ruby_value.to_s)
    when ::Integer then Number.new(:int, ruby_value)
    when ::Float, ::BigDecimal then Number.new(:double, ruby_value)
    when ::Hash
      Map.new(ruby_value.to_h { |k, v| [to_value(k), to_value(v)] })
    when ::Array
      List.new(ruby_value.map { |v| to_value(v) })
    when true, false then Bool.new(ruby_value)
    when nil then Null.new
    when Time then Timestamp.new(ruby_value)
    else raise BindingError, "can't convert #{ruby_value} to CEL type"
    end
  end

  class Value
    attr_reader :type

    def initialize(type)
      @type = type
    end

    def to_ruby
      raise "Cannot convert bare value to ruby"
    end
  end
end

require "cel/values/bool"
require "cel/values/bytes"
require "cel/values/duration"
require "cel/values/list"
require "cel/values/map"
require "cel/values/null"
require "cel/values/number"
require "cel/values/string"
require "cel/values/timestamp"

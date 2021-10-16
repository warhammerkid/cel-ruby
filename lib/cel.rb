# frozen_string_literal: true

require "cel/version"

require "cel/parser"
require "cel/context"
require "cel/checker"
require "cel/program"
require "cel/environment"

module Cel
  class Error < StandardError; end




  class Type
    def initialize(type)
      @type = type
    end

    def ==(other)
      other == @type || super
    end

    def to_str
      @type.to_s
    end

    def type
      TYPES[:type]
    end
  end

  class ListType < Type
    def initialize(type_list)
      @type_list = type_list
    end

    def get(idx)
      @type_list[idx]
    end
  end

  class MapType < Type
    def initialize(type_map)
      @type_map = type_map
    end

    def get(attrib)
      _, value = @type_map.find { |k, _| k == attrib.to_s }
      value
    end
  end

  # Primitive Cel Types

  PRIMITIVE_TYPES = %i[int uint double bool string bytes list map null_type type]
  TYPES = Hash[
    PRIMITIVE_TYPES.map {|typ| [typ, Type.new(typ)]}
  ]
  TYPES[:type] == Type.new(:type)
end
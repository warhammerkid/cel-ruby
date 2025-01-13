# frozen_string_literal: true

module Cel
  class Type
    def initialize(type)
      @type = type
    end

    def ==(other)
      other == @type || super
    end

    def to_sym
      @type
    end

    def to_str
      @type.to_s
    end

    alias_method :to_s, :to_str

    def type
      TYPES[:type]
    end
  end

  class ListType < Type
    attr_reader :element_type

    def self.[](element_type)
      element_type = TYPES.fetch(element_type) unless element_type.is_a?(Type)
      new(element_type)
    end

    def initialize(element_type)
      raise "Element type must be a type: #{element_type}" unless element_type.is_a?(Type)

      super(:list)
      @element_type = element_type
    end
  end

  class MapType < Type
    attr_reader :key_type, :element_type

    def self.[](key_type, element_type)
      key_type = TYPES.fetch(key_type) unless key_type.is_a?(Type)
      element_type = TYPES.fetch(element_type) unless element_type.is_a?(Type)
      new(key_type, element_type)
    end

    def initialize(key_type, element_type)
      raise "Key type must be a type: #{key_type}" unless key_type.is_a?(Type)
      raise "Element type must be a type: #{element_type}" unless element_type.is_a?(Type)

      super(:map)
      @key_type = key_type
      @element_type = element_type
    end
  end

  # Primitive Cel Types

  PRIMITIVE_TYPES = %i[int uint double bool string bytes list map timestamp duration null_type type].freeze
  TYPES = (PRIMITIVE_TYPES - %i[list map] + %i[any]).to_h { |typ| [typ, Type.new(typ)] }
  TYPES[:list] = ListType[:any]
  TYPES[:map] = MapType[:any, :any]
end

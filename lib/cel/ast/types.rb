# frozen_string_literal: true

module Cel
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

    alias_method :to_s, :to_str

    def type
      TYPES[:type]
    end

    def cast(value)
      value = value.value if value.is_a?(Literal)

      case @type
      when :int
        Number.new(:int, Integer(value))
      when :uint
        Number.new(:uint, Integer(value).abs)
      when :double
        Number.new(:double, Float(value))
      when :string
        String.new(String(value))
      when :bytes
        Bytes.new(value.bytes)
      when :bool
        Bool.new(value)
      when :timestamp
        Timestamp.new(value)
      when :duration
        Duration.new(value)
      when :any
        value
      else
        raise Error, "unsupported cast operation to #{@type}"
      end
    end
  end

  class ListType < Type
    attr_accessor :element_type

    def initialize(type_list)
      super(:list)
      @type_list = type_list
      @element_type = @type_list.empty? ? TYPES[:any] : @type_list.sample.type
    end

    def get(idx)
      @type_list[idx]
    end

    def ==(other)
      other == :list || super
    end

    def cast(value)
      List.new(value)
    end
  end

  class MapType < Type
    attr_accessor :element_type

    def initialize(type_map)
      super(:map)
      @type_map = type_map
      @element_type = @type_map.empty? ? TYPES[:any] : @type_map.keys.sample.type
    end

    def get(attrib)
      _, value = @type_map.find { |k, _| k == attrib.to_s }
      value
    end

    def ==(other)
      other == :map || super
    end

    def cast(value)
      Map.new(value)
    end
  end

  # Primitive Cel Types

  PRIMITIVE_TYPES = %i[int uint double bool string bytes list map timestamp duration null_type type].freeze
  COLTYPES = %i[list map].freeze
  TYPES = (PRIMITIVE_TYPES - COLTYPES).to_h { |typ| [typ, Type.new(typ)] }
  TYPES[:type] = Type.new(:type)
  TYPES[:any] = Type.new(:any)

  module CollectionTypeFetch
    def [](*args)
      col_type, elem_type = args

      return super unless COLTYPES.include?(col_type)

      return super if args.size > 2

      elem_type ||= :any

      type = case col_type
             when :list
               ListType.new([])
             when :map
               MapType.new({})
      end

      type.element_type = super(*elem_type)
      type
    end
  end

  TYPES.singleton_class.prepend(CollectionTypeFetch)
end

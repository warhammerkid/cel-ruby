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

    def type
      TYPES[:type]
    end

    def cast(value)
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
      else
        raise Error, "unsupported cast operation to #{@type}"
      end
    end
  end

  class ListType < Type
    def initialize(type_list)
      @type_list = type_list
      super(:list)
    end

    def get(idx)
      @type_list[idx]
    end
  end

  class MapType < Type
    def initialize(type_map)
      @type_map = type_map
      super(:map)
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
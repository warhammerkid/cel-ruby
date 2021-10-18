require "delegate"

module Cel
  LOGICAL_OPERATORS =  %w[< <= >= > == != in]
  ADD_OPERATORS = %w[+ -]
  MULTI_OPERATORS = %w[* / %]

  class Identifier < SimpleDelegator
    attr_reader :id

    attr_accessor :type

    def initialize(identifier)
      @id = identifier
      @type = :any
      super(@id)
    end

    def ==(other)
      super || other.to_s == @id.to_s
    end
  end

  class Message < SimpleDelegator
    attr_reader :type, :struct

    def initialize(type, struct)
      check(struct)
      @struct = Struct.new(*struct.keys.map(&:to_sym)).new(*struct.values)
      @type = type.is_a?(Type) ? type : MapType.new(struct)
      super(@struct)
    end

    def field?(key)
      !@type.get(key).nil?
    end

    private

    # For a message, the field names are identifiers.
    def check(struct)
      unless struct.each_key.all? { |key| key.is_a?(Identifier) }
        raise Error, "#{struct} is invalid (keys must be identifiers)"
      end
    end
  end


  class Invoke
    attr_reader :var, :func, :args

    def initialize(func:, var: nil, args: nil)
      @var = var
      @func = func.to_sym
      @args = args
    end

    def ==(other)
      super || (
        other.respond_to?(:to_ary) &&
        [@var, @func, @args].compact == other
      )
    end

    def to_s
      if var
        if func == :[]
          "#{var}[#{"(#{Array(args).join(', ')})" if args}"
        else
          "#{var}.#{func}#{"(#{Array(args).join(', ')})" if args}"
        end
      else
        "#{func}#{"(#{Array(args).join(', ')})" if args}"
      end
    end
  end

  class Literal < SimpleDelegator
    attr_reader :type, :value

    def initialize(type, value)
      @type = type.is_a?(Type) ? type : TYPES[type]
      @value = value
      super(value)
    end

    def ==(other)
      @value == other || super
    end

    private

    def check; end
  end

  class Number < Literal
  end

  class Bool < Literal
    def initialize(value)
      super(:bool, value)
    end
  end

  class Null < Literal
    def initialize()
      super(:null_type, nil)
    end
  end

  class String < Literal
    def initialize(value)
      super(:string, value)
    end
  end

  class Bytes < Literal
    def initialize(value)
      super(:bytes, value.force_encoding(Encoding::BINARY))
    end
  end

  class List < Literal
    def initialize(value)
      super(ListType.new(value), value)
    end

    def ==(other)
      super || (
        other.respond_to?(:to_ary) &&
        @value.zip(other).all?{|x1, x2| x1 == x2 }
      )
    end
  end

  class Map < Literal
    def initialize(value)
      super(MapType.new(value), value)
    end

    def ==(other)
      super || (
        other.respond_to?(:to_hash) &&
        @value.zip(other).all?{|(x1, y1), (x2, y2)| x1 == x2 && y1 == y2 }
      )
    end

    def respond_to_missing?(meth, *args)
      super || @value.keys.any? { |k| k.to_s == meth.to_s }
    end

    def method_missing(meth, *args)
      key = @value.keys.find { |k| k.to_s == meth.to_s } or return super

      @value[key]
    end

    private

    ALLOWED_TYPES = %i[int uint bool string]

    # For a map, the entry keys are sub-expressions that must evaluate to values
    # of an allowed type (int, uint, bool, or string)
    def check
      unless @value.each_key.all? { |key| ALLOWED_TYPES.include?(key.type) }
        raise Error, "#{self} is invalid (keys must be of an allowed type (int, uint, bool, or string)"
      end
    end
  end

  class Group
    attr_reader :value
    def initialize(value)
      @value = value
    end
  end

  class Operation
    attr_reader :op, :operands

    def initialize(op, operands)
      @op = op
      @operands = operands
    end

    def ==(other)
      if other.is_a?(Array)
        other.size == @operands.size + 1 &&
        other.first == @op &&
        other.slice(1..-1).zip(@operands).all?{ |x1, x2| x1 == x2 }
      else
        super
      end
    end

    # def type
    #   case @op
    #   when *LOGICAL_OPERATORS, "&&", "||"
    #     @type = :bool
    #   when *MULTI_OPERATORS
    #     types = @operands.map(&:type).uniq
    #     if types.size == 1
    #       @type = :any if types.include?(:any)
    #       @type ||= :number if types.include?(:number)
    #     end
    #   when "!"
    #     types = @operands.map(&:type).uniq
    #     if types.size == 1
    #       @type = :any if types.include?(:any)
    #       @type ||= :bool if types.include?(:bool)
    #     end
    #   when "-"
    #     if @operands.size == 1
    #       # negative
    #       if types.size == 1
    #         @type = :any if types.include?(:any)
    #         @type ||= :integer if types.include?(:integer)
    #       end
    #     else

    #     end

    #   when *ADD_OPERATORS
    #     types = @operands.map(&:type).uniq
    #     if types.size == 1
    #       @type = :any if types.include?(:any)
    #       @type ||= :list if @op != "-" && types.include?(:list)
    #       @type ||= :string if types.include?(:string)
    #       @type ||= :number if types.include?(:number)
    #     end

    #   end
    #   return if @type

    #   raise Error, "operand types invalid for #{@op} (#{types.join(", ")})"
    # end
  end

  class Condition
    attr_reader :if, :then, :else

    def initialize(if_, then_, else_)
      @if = if_
      @then = then_
      @else = else_
    end
  end
end
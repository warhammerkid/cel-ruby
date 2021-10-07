module Cel
  LOGICAL_OPERATORS =  %w[< <= >= > == != in]
  ADD_OPERATORS = %w[+ -]
  MULTI_OPERATORS = %w[* / %]

  class Identifier
    attr_reader :id

    attr_accessor :type

    def initialize(identifier)
      @id = identifier
      @type = :any
    end

    def ==(other)
      super || other.to_s == @id.to_s
    end
  end

  class WithStruct
    attr_reader :val, :struct

    def initialize(val, struct)
      @val = val
      @struct = struct
    end
  end


  class Invoke
    attr_reader :var, :func, :args

    def initialize(func:, var: nil, args: nil)
      @var = var
      @func = func
      @args = args
    end
  end

  class Literal
    attr_reader :type, :value

    def initialize(type, value)
      @type = type
      @value = value
    end

    def ==(other)
      @value == other || super
    end
  end

  class Number < Literal
    def initialize(value)
      super(:number, value)
    end
  end

  class Bool < Literal
    def initialize(value)
      super(:bool, value)
    end
  end

  class Null < Literal
    def initialize()
      super(:null, nil)
    end
  end

  class String < Literal
    def initialize(value)
      super(:string, value)
    end
  end

  class List < Literal
    def initialize(value)
      super(:list, value)
    end

    def ==(other)
      super || (
        other.respond_to?(:to_ary) &&
        @value.zip(other).all?{|x1, x2| x1 == x2 }
      )
    end
  end

  class Struct < Literal
    def initialize(value)
      super(:struct, value)
    end

    def ==(other)
      super || (
        other.respond_to?(:to_hash) &&
        @value.zip(other).all?{|(x1, y1), (x2, y2)| x1 == x2 && y1 == y2 }
      )
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
      @if = cond
      @then = then_
      @else = else_
    end
  end
end
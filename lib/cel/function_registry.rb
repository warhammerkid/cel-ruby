# frozen_string_literal: true

module Cel
  class FunctionRegistry
    def initialize(legacy_declarations)
      @bindings = {}
      convert_legacy_declarations(legacy_declarations)
    end

    def lookup_function(call_ast, args)
      name_matches = @bindings[call_ast.function]
      return nil if name_matches.nil?

      matches = name_matches[!call_ast.target.nil?]
      return nil if matches.nil?

      # Return match
      arg_types = args.map(&:type)
      matches.find do |binding|
        next unless binding.arg_types.size == arg_types.size

        binding.arg_types.zip(arg_types).all? do |expected, actual|
          expected == :any || expected == actual
        end
      end
    end

    def extend_functions(mod)
      FunctionBindings.bindings(mod).each { |b| add_binding(b) }
    end

    private

    def convert_legacy_declarations(legacy_declarations)
      legacy_declarations.each do |name, func|
        unless func.is_a?(Cel::Function)
          type_args = Array.new(func.arity, :any)
          func = Cel::Function(*type_args, return_type: :any, &func)
        end

        binding = FunctionBindings::BindingDef.new(
          name.to_s,
          func.types,
          func.type,
          false,
          func.method(:call)
        )
        add_binding(binding)
      end
    end

    def add_binding(binding)
      @bindings[binding.name] ||= {}
      @bindings[binding.name][binding.is_receiver] ||= []
      @bindings[binding.name][binding.is_receiver] << binding
    end
  end

  # Legacy Function class for bindings
  class Function
    attr_reader :types, :type

    def initialize(*types, return_type: nil, &func)
      unless func.nil?
        types = Array.new(func.arity) { TYPES[:any] } if types.empty?
        raise(Error, "number of arg types does not match number of yielded args") unless types.size == func.arity
      end
      @types = types.map { |typ| typ.is_a?(Type) ? typ : TYPES[typ] }
      @type = if return_type.nil?
        TYPES[:any]
      else
        return_type.is_a?(Type) ? return_type : TYPES[return_type]
      end
      @func = func
    end

    def call(*args)
      Cel.to_value(@func.call(*args.map(&:to_ruby)))
    end
  end

  mod = self
  mod.define_singleton_method(:Function) do |*args, **kwargs, &blk|
    mod::Function.new(*args, **kwargs, &blk)
  end
end

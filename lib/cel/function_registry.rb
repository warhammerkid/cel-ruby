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

      # Calculate arg types for lookup
      arg_types = args.map do |arg|
        case arg
        when Cel::Type then :type
        when Cel::List then :list
        when Cel::Map then :map
        when Cel::Literal then arg.type.to_str.to_sym
        when Cel::Types::Message then :message
        else raise "Could not determine arg type: #{arg.inspect}"
        end
      end

      # Return match
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
          func.types.map { |t| t.to_str.to_sym },
          func.type.to_str.to_sym,
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
end

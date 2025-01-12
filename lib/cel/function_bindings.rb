# frozen_string_literal: true

module Cel
  # FunctionBindings is a metaprogramming module to simplify defining custom
  # function bindings with types
  #
  module FunctionBindings
    CEL_BINDINGS = :@__cel_bindings__
    CEL_FUNC = :@__cel_func__

    def self.extended(mod)
      mod.singleton_class? ? mod.include(Hooks) : mod.extend(Hooks)
    end

    # Returns defined bindings on the given module. Returns an empty array if
    # there are no defined bindings.
    #
    def self.bindings(mod)
      if mod.instance_variable_defined?(CEL_BINDINGS)
        mod.instance_variable_get(CEL_BINDINGS)
      else
        mod.instance_variable_set(CEL_BINDINGS, [])
      end
    end

    def cel_func(&block)
      helper = TypeHelper.new
      helper.instance_exec(&block)
      instance_variable_set(CEL_FUNC, helper.bindings)
    end

    class TypeHelper
      VALID_TYPES = %i[int uint double bool string bytes list map timestamp duration type message any].freeze

      attr_reader :bindings

      def initialize
        @bindings = []
      end

      def global_function(name, args, return_type)
        add_binding(name, args, return_type, false)
      end

      def receiver_function(name, receiver, args, return_type)
        add_binding(name, [receiver] + args, return_type, true)
      end

      private

      def add_binding(name, arg_types, return_type, is_receiver)
        arg_types.each { |a| raise "Invalid argument type: #{a}" unless VALID_TYPES.include?(a) }
        raise "Invalid return type: #{return_type}" unless VALID_TYPES.include?(return_type)

        @bindings << BindingDef.new(name, arg_types, return_type, is_receiver)
      end
    end

    module Hooks
      def singleton_method_added(m)
        cel_bindings = FunctionBindings.bindings(self)

        # Lookup bindings for the method
        bindings = instance_variable_get(CEL_FUNC) || singleton_class.instance_variable_get(CEL_FUNC)
        instance_variable_set(CEL_FUNC, nil)
        singleton_class.instance_variable_set(CEL_FUNC, nil)

        # Save bindings to module instance variable to be retrieved by
        # Environment#extend_functions.
        if bindings
          bound_method = method(m)
          bindings.each do |b|
            b.method_ref = bound_method
            cel_bindings << b
          end
        end

        super
      end

      def method_added(m)
        cel_bindings = FunctionBindings.bindings(self)

        # Lookup bindings for the method
        bindings = instance_variable_get(CEL_FUNC)
        instance_variable_set(CEL_FUNC, nil)

        # Save bindings to class instance variable to be retrieved by
        # Environment#extend_functions.
        if bindings
          unbound_method = instance_method(m)
          bindings.each do |b|
            b.method_ref = unbound_method
            cel_bindings << b
          end
        end

        super
      end
    end

    class BindingDef
      attr_reader :name, :arg_types, :return_type, :is_receiver
      attr_writer :method_ref

      def initialize(name, arg_types, return_type, is_receiver, method_ref = nil)
        @name = name
        @arg_types = arg_types
        @return_type = return_type
        @is_receiver = is_receiver
        @method_ref = method_ref
      end

      def call(*args)
        if @method_ref.is_a?(UnboundMethod)
          @method_ref.bind_call(*args)
        else
          @method_ref.call(*args)
        end
      end
    end
  end
end

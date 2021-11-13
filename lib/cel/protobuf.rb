# frozen_string_literal: true

require "time"

module Cel
  module Protobuf
    module CheckExtensions
      def self.included(klass)
        super
        klass.alias_method :check_standard_func_without_protobuf, :check_standard_func
        klass.alias_method :check_standard_func, :check_standard_func_with_protobuf

        klass.alias_method :check_invoke_without_protobuf, :check_invoke
        klass.alias_method :check_invoke, :check_invoke_with_protobuf
      end

      private

      def check_invoke_with_protobuf(funcall)
        var = funcall.var

        return check_standard_func(funcall) unless var

        var_type = case var
                   when Identifier
                     check_identifier(var)
                   when Invoke
                     check_invoke(var)
                   else
                     var.type
        end

        return check_invoke_without_protobuf(funcall, var_type) if var_type.is_a?(Cel::Type)
        return check_invoke_without_protobuf(funcall, var_type) unless var_type < Google::Protobuf::MessageExts

        func = funcall.func

        attribute = var_type.descriptor.lookup(func.to_s)

        raise NoSuchFieldError.new(var, func) unless attribute

        # TODO: return super to any, or raise error?

        type = attribute.type

        case type
        when :int32, :int64, :sint32, :sint64, :sfixed32, :sfixed64
          TYPES[:int]
        when :uint32, :uint64, :fixed32, :fixed64
          TYPES[:uint]
        when :float, :double
          TYPES[:double]
        when :bool, :string, :bytes
          TYPES[type]
        when :repeated
          TYPES[:list]
        when :map
          TYPES[:map]
        when :oneof
          TYPES[:any]
        else
          type
        end
      end

      def check_standard_func_with_protobuf(funcall)
        func = funcall.func
        args = funcall.args

        case func
        when :duration
          check_arity(func, args, 1)
          unsupported_type(funcall) unless args.first.is_a?(String)

          return Google::Protobuf::Duration
        when :timestamp
          check_arity(func, args, 1)
          unsupported_type(funcall) unless args.first.is_a?(String)

          return Google::Protobuf::Timestamp
        end

        check_standard_func_without_protobuf(funcall)
      end
    end

    module EvaluateExtensions
      def self.included(klass)
        super
        klass.alias_method :evaluate_standard_func_without_protobuf, :evaluate_standard_func
        klass.alias_method :evaluate_standard_func, :evaluate_standard_func_with_protobuf

        klass.alias_method :evaluate_invoke_without_protobuf, :evaluate_invoke
        klass.alias_method :evaluate_invoke, :evaluate_invoke_with_protobuf
      end

      private

      def evaluate_invoke_with_protobuf(invoke)
        var = invoke.var

        return evaluate_standard_func(invoke) unless var

        var = case var
              when Identifier
                evaluate_identifier(var)
              when Invoke
                evaluate_invoke(var)
              else
                var
        end

        return evaluate_invoke_without_protobuf(invoke, var) unless var.is_a?(Google::Protobuf::MessageExts)

        func = invoke.func

        var.public_send(func)
      end

      def evaluate_standard_func_with_protobuf(funcall)
        func = funcall.func
        args = funcall.args

        case func
        when :duration
          seconds = 0
          nanos = 0
          args.first.value.scan(/([0-9]*(?:\.[0-9]*)?)([a-z]+)/) do |duration, units|
            case units
            when "h"
              seconds += Cel.to_numeric(duration) * 60 * 60
            when "m"
              seconds += Cel.to_numeric(duration) * 60
            when "s"
              seconds += Cel.to_numeric(duration)
            when "ms"
              nanos += Cel.to_numeric(duration) * 1000 * 1000
            when "us"
              nanos += Cel.to_numeric(duration) * 1000
            when "ns"
              nanos += Cel.to_numeric(duration)
            else
              raise EvaluateError, "#{units} is unsupported"
            end
          end
          return Google::Protobuf::Duration.new(seconds: seconds, nanos: nanos)
        when :timestamp
          time = Time.parse(args.first)
          return Google::Protobuf::Timestamp.from_time(time)
        end

        evaluate_standard_func_without_protobuf(funcall)
      end
    end

    module ContextExtensions
      def self.included(klass)
        super
        klass.alias_method :to_cel_type_without_protobuf, :to_cel_type
        klass.alias_method :to_cel_type, :to_cel_type_with_protobuf
      end

      def to_cel_type_with_protobuf(v)
        return v if v.is_a?(Google::Protobuf::MessageExts)

        to_cel_type_without_protobuf(v)
      end
    end
  end

  Checker.include(Protobuf::CheckExtensions)
  Program.include(Protobuf::EvaluateExtensions)
  Context.include(Protobuf::ContextExtensions)
end

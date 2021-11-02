# frozen_string_literal: true

require "time"

module Cel
  module Protobuf
    module CheckExtensions
      def self.included(klass)
        super
        klass.alias_method :check_standard_func_without_protobuf, :check_standard_func
        klass.alias_method :check_standard_func, :check_standard_func_with_protobuf
      end

      private

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
      end

      private

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
              raise Error, "#{units} is unsupported"
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
  end

  Checker.include(Protobuf::CheckExtensions)
  Program.include(Protobuf::EvaluateExtensions)
end

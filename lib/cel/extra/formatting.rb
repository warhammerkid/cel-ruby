# frozen_string_literal: true

require "strscan"

module Cel
  module Extra
    class Formatting
      def self.convert_to_string(value)
        return "null" if value.is_a?(Cel::Null)

        value.cast_to_type(TYPES[:string]).value
      end

      def self.convert_to_integer(format_str, value)
        return format(format_str, value.value) if value.is_a?(Cel::Number) && value.type != :double

        raise EvaluateError, "Cannot convert #{value} to integer"
      end

      def self.convert_to_float(format_str, value)
        if value.is_a?(Cel::String)
          case value.value
          when "NaN" then return "NaN"
          when "Infinity" then return "∞"
          when "-Infinity" then return "-∞"
          end
        elsif value.is_a?(Cel::Number) && value.type == :double
          return format(format_str, value.value)
        end

        raise EvaluateError, "Cannot convert #{value} to float"
      end

      def self.convert_to_hex(format_str, value)
        lower_case = format_str[1] == "x"
        if value.is_a?(Cel::String) || value.is_a?(Cel::Bytes)
          hex = value.value.unpack1("H*")
          lower_case ? hex : hex.upcase
        elsif value.is_a?(Cel::Number) && value.type != :double
          format(format_str, value.value)
        else
          raise EvaluateError, "Cannot convert #{value} to hexadecimal"
        end
      end

      def self.convert_to_binary(value)
        if value.is_a?(Cel::Number) && value.type != :double
          format("%b", value.value)
        elsif value.is_a?(Cel::Bool)
          value.value ? "1" : "0"
        else
          raise EvaluateError, "Cannot convert #{value} to binary"
        end
      end

      CLAUSES = {
        string: method(:convert_to_string),
        decimal: method(:convert_to_integer),
        float: method(:convert_to_float),
        exponential: method(:convert_to_float),
        binary: method(:convert_to_binary),
        hex: method(:convert_to_hex),
        octal: method(:convert_to_integer),
      }.freeze

      def initialize(format_string)
        @format_string = format_string
        @clauses = []
        @parsed_format_string = nil
      end

      def call(args_list)
        parse!

        args = args_list.value
        raise Cel::Error, "Arg count mismatch: #{@clauses.size} vs #{args.size}" unless @clauses.size == args.size

        format_args = args.zip(@clauses).map do |arg, (f, method)|
          method.arity == 1 ? method.call(arg) : method.call(f, arg)
        end
        format(@parsed_format_string, *format_args)
      end

      private

      def parse!
        return if @parsed_format_string

        scanner = StringScanner.new(@format_string)
        @parsed_format_string = ::String.new(capacity: @format_string.size)
        until scanner.eos?
          if scanner.scan(/[^%]+/) || scanner.scan("%%")
            @parsed_format_string << scanner.matched
            next
          end

          method =
            if scanner.scan("%s")
              CLAUSES.fetch(:string)
            elsif scanner.scan("%d")
              CLAUSES.fetch(:decimal)
            elsif scanner.scan(/%(\.\d+)?f/)
              CLAUSES.fetch(:float)
            elsif scanner.scan(/%(\.\d+)?e/)
              CLAUSES.fetch(:exponential)
            elsif scanner.scan("%b")
              CLAUSES.fetch(:binary)
            elsif scanner.scan(/%[xX]/)
              CLAUSES.fetch(:hex)
            elsif scanner.scan("%o")
              CLAUSES.fetch(:octal)
            else
              raise Cel::Error, "Could not parse format string at #{scanner.pos}: #{@format_string.inspect}"
            end
          @clauses << [scanner.matched, method]
          @parsed_format_string << "%s"
        end
      end
    end
  end
end

# frozen_string_literal: true

# require 'google/protobuf/struct_pb'
# require 'google/protobuf/wrappers_pb'
# require 'google/protobuf/any_pb'

module Cel
  module Protobuf
    def self.convert_from_type(type, value)
      case type
      when "Any", "google.protobuf.Any"
        # TODO
      when "ListValue", "google.protobuf.ListValue"
        value = value.nil? ? List.new([]) : value[Identifier.new("values")]
      when "Struct", "google.protobuf.Struct"
        value = value.nil? ? Map.new({}) : value[Identifier.new("fields")]
      when "Value", "google.protobuf.Value"
        return Null.new if value.nil?

        key = value.keys.first

        value = value.fetch(key, value)

        value = Number.new(:double, value) if key == "number_value"

        value
      when "BoolValue", "google.protobuf.BoolValue"
        value = value.nil? ? Bool.new(false) : value[Identifier.new("value")]
      when "BytesValue", "google.protobuf.BytesValue"
        value = value[Identifier.new("value")]
      when "DoubleValue", "google.protobuf.DoubleValue",
           "FloatValue", "google.protobuf.FloatValue"
        value = value.nil? ? Number.new(:double, 0.0) : value[Identifier.new("value")]
        value.type = TYPES[:double]
      when "Int32Value", "google.protobuf.Int32Value",
           "Int64Value", "google.protobuf.Int64Value"
        value = value.nil? ? Number.new(:int, 0) : value[Identifier.new("value")]
      when "Uint32Value", "google.protobuf.Uint32Value",
           "Uint64Value", "google.protobuf.Uint64Value"
        value = value.nil? ? Number.new(:uint, 0) : value[Identifier.new("value")]
      when "NullValue", "google.protobuf.NullValue"
        value = Null.new
      when "StringValue", "google.protobuf.StringValue"
        value = value.nil? ? String.new(+"") : value[Identifier.new("value")]
      end
      value
    end

    def self.try_invoke_from(var, func, args)
      case var
      when "Any", "google.protobuf.Any",
        "ListValue", "google.protobuf.ListValue",
        "Struct", "google.protobuf.Struct",
        "Value", "google.protobuf.Value",
        "BoolValue", "google.protobuf.BoolValue",
        "BytesValue", "google.protobuf.BytesValue",
        "DoubleValue", "google.protobuf.DoubleValue",
        "FloatValue", "google.protobuf.FloatValue",
        "Int32Value", "google.protobuf.Int32Value",
        "Int64Value", "google.protobuf.Int64Value",
        "Uint32Value", "google.protobuf.Uint32Value",
        "Uint64Value", "google.protobuf.Uint64Value",
        "NullValue", "google.protobuf.NullValue",
        "StringValue", "google.protobuf.StringValue"
        protoclass = var.split(".").last
        protoclass = Google::Protobuf.const_get(protoclass)

        value = if args.nil? && protoclass.constants.include?(func.to_sym)
          protoclass.const_get(func)
        else
          protoclass.__send__(func, *args)
        end

        Literal.to_cel_type(value)
      end
    end
  end
end

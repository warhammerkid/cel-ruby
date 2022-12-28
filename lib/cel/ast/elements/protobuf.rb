# frozen_string_literal: true

require "google/protobuf/struct_pb"
require "google/protobuf/wrappers_pb"
require "google/protobuf/any_pb"
require "google/protobuf/well_known_types"

module Cel
  module Protobuf
    module_function

    def convert_from_protobuf(msg)
      case msg
      when Google::Protobuf::Any

        any.unpack(type_msg).to_ruby
      when Google::Protobuf::ListValue
        msg.to_a
      when Google::Protobuf::Struct
        msg.to_h
      when Google::Protobuf::Value
        msg.to_ruby
      when Google::Protobuf::BoolValue,
           Google::Protobuf::BytesValue,
           Google::Protobuf::DoubleValue,
           Google::Protobuf::FloatValue,
           Google::Protobuf::Int32Value,
           Google::Protobuf::Int64Value,
           Google::Protobuf::UInt32Value,
           Google::Protobuf::UInt64Value,
           Google::Protobuf::NullValue,
           Google::Protobuf::StringValue
        msg.value
      when Google::Protobuf::Timestamp
        msg.to_time
      when Google::Protobuf::Duration
        Cel::Duration.new(seconds: msg.seconds, nanos: msg.nanos)
      else
        raise Error, "#{msg.class}: protobuf to cel unsupported"
      end
    end

    def convert_from_type(type, value)
      case type
      when "Any", "google.protobuf.Any"
        type_url = value[Identifier.new("type_url")].value
        _, type_msg = type_url.split("/", 2)
        type_msg = const_get(type_msg.split(".").map(&:capitalize).join("::"))
        encoded_msg = value[Identifier.new("value")].value.pack("C*")
        any = Google::Protobuf::Any.new(type_url: type_url, value: encoded_msg)
        value = Literal.to_cel_type(any.unpack(type_msg).to_ruby)
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
      when "Uint32Value", "google.protobuf.UInt32Value",
           "Uint64Value", "google.protobuf.UInt64Value"
        value = value.nil? ? Number.new(:uint, 0) : value[Identifier.new("value")]
      when "NullValue", "google.protobuf.NullValue"
        value = Null.new
      when "StringValue", "google.protobuf.StringValue"
        value = value.nil? ? String.new(+"") : value[Identifier.new("value")]
      when "Timestamp", "google.protobuf.Timestamp"
        seconds = value.fetch(Identifier.new("seconds"), 0)
        nanos = value.fetch(Identifier.new("nanos"), 0)
        value = Timestamp.new(Time.at(seconds, nanos, :nanosecond))
      when "Duration", "google.protobuf.Duration"
        seconds = value.fetch(Identifier.new("seconds"), 0)
        nanos = value.fetch(Identifier.new("nanos"), 0)
        value = Duration.new(seconds: seconds, nanos: nanos)
      end
      value
    end

    def try_invoke_from(var, func, args)
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
        "StringValue", "google.protobuf.StringValue",
        "Timestamp", "google.protobuf.Timestamp",
        "Duration", "google.protobuf.Duration"
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

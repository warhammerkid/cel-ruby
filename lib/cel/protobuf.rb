# frozen_string_literal: true

begin
  require "base64"

  require "google/protobuf/descriptor_pb"
  require "google/protobuf/struct_pb"
  require "google/protobuf/wrappers_pb"
  require "google/protobuf/any_pb"
  require "google/protobuf/well_known_types"

  require "cel/types/message"

  module Cel
    module Protobuf
      pool = Google::Protobuf::DescriptorPool.generated_pool

      NUMERIC_TYPES = %i[
        int32 int64 uint32 uint64 float double sint32 sint64
        fixed32 fixed64 sfixed32 sfixed64
      ].to_h { |type| [type, true] }.freeze

      ANY_DESCRIPTOR = pool.lookup("google.protobuf.Any")
      LIST_DESCRIPTOR = pool.lookup("google.protobuf.ListValue")
      STRUCT_DESCRIPTOR = pool.lookup("google.protobuf.Struct")
      VALUE_DESCRIPTOR = pool.lookup("google.protobuf.Value")

      # Container struct for representing a repeated field type to cast to
      RepeatedType = Struct.new(:type, :type_descriptor)

      # Container struct for representing a map type to cast to
      MapType = Struct.new(:key_type, :value_type, :value_descriptor)

      # Simple helper to convert an enum symbol into a value
      def self.enum_lookup_name(enum_descriptor, name_sym)
        if name_sym.is_a?(Integer)
          # This might happen if you set an enum field to an invalid number so
          # just return it
          name_sym
        elsif enum_descriptor.respond_to?(:lookup_name)
          enum_descriptor.lookup_name(name_sym)
        else
          # JRuby doesn't implement lookup_name, so we have to do it the slow way
          enum_descriptor.find { |name, _| name == name_sym }[1]
        end
      end

      # Simple helper to convert the given field descriptor to a type object
      # that can be passed to #cast_to_proto(type).
      def self.field_descriptor_type(fd)
        subtype = fd.subtype
        if fd.label == :repeated
          if !subtype || !subtype.options.map_entry
            RepeatedType.new(fd.type, subtype)
          else
            key_descriptor = subtype.lookup("key")
            value_descriptor = subtype.lookup("value")
            MapType.new(key_descriptor.type, value_descriptor.type, value_descriptor.subtype)
          end
        else
          subtype || fd.type
        end
      end

      # Converts the given Cel value to the given proto-compatible type
      def self.proto_to_cel(value, type)
        case type
        when :int32, :int64, :sint32, :sint64, :sfixed32, :sfixed64
          Cel::Number.new(:int, value)
        when :uint32, :uint64, :fixed32, :fixed64
          Cel::Number.new(:uint, value)
        when :float, :double
          Cel::Number.new(:double, value)
        when :bool
          Cel::Bool.new(value)
        when :string
          Cel::String.new(value)
        when :bytes
          Cel::Bytes.new(value.unpack("C*"))
        when Google::Protobuf::EnumDescriptor
          Cel::Number.new(:int, Cel::Protobuf.enum_lookup_name(type, value))
        when Google::Protobuf::Descriptor
          return Cel::Types::Message.new(value) if value

          # If accessing a message field that isn't set, if it's a wrapper type
          # return null. Otherwise return a new message with the correct type.
          if Cel::Number::WRAPPER_DESCRIPTORS.key?(type) || type == Cel::Bool::BOOL_DESCRIPTOR ||
             type == Cel::String::STRING_DESCRIPTOR || type == Cel::Bytes::BYTES_DESCRIPTOR
            Cel::Null.new
          else
            Cel::Types::Message.new(type.msgclass.new)
          end
        when Cel::Protobuf::RepeatedType
          list_type = type.type_descriptor || type.type
          Cel::List.new(value.map { |v| proto_to_cel(v, list_type) })
        when Cel::Protobuf::MapType
          map_type = type.value_descriptor || type.value_type
          Cel::Map.new(value.to_h { |k, v| [proto_to_cel(k, type.key_type), proto_to_cel(v, map_type)] })
        else
          raise EvaluateError, "Unexpected field descriptor type: #{fd.type}"
        end
      end

      # TODO: This probably needs to be completely re-worked
      def self.lookup_enum(identifier)
        EnumLookup.new(identifier.id)
      end

      # Magical object that eventually returns the enum value if enough selects
      # are chained to it
      class EnumLookup
        def initialize(name)
          @name = name
        end

        def select(field)
          enum = Google::Protobuf::DescriptorPool.generated_pool.lookup(@name)
          if enum.is_a?(Google::Protobuf::EnumDescriptor)
            # Return the enum value
            Cel::Number.new(:int, Cel::Protobuf.enum_lookup_name(enum, field.to_sym))
          else
            # Keep chaining in the hopes it's a valid enum eventually
            EnumLookup.new("#{@name}.#{field}")
          end
        end
      end
    end

    class Literal
      class << self
        alias_method :to_cel_type_without_proto, :to_cel_type
        def to_cel_type(val)
          case val
          when Google::Protobuf::MessageExts
            Cel::Types::Message.new(val)
          when Cel::Types::Message
            val
          when Google::Protobuf::RepeatedField
            List.new(val.to_a)
          when Google::Protobuf::Map
            Map.new(val.to_h)
          else
            to_cel_type_without_proto(val)
          end
        end
      end
    end

    class Number
      pool = Google::Protobuf::DescriptorPool.generated_pool
      WRAPPER_DESCRIPTORS = [
        "google.protobuf.DoubleValue", "google.protobuf.FloatValue",
        "google.protobuf.Int64Value", "google.protobuf.Int32Value",
        "google.protobuf.UInt64Value", "google.protobuf.UInt32Value"
      ].to_h { |type| [pool.lookup(type), true] }.freeze
      PREFERRED_PROTO_WRAPPER = {
        Cel::TYPES[:int] => Google::Protobuf::Int64Value,
        Cel::TYPES[:uint] => Google::Protobuf::UInt64Value,
        Cel::TYPES[:double] => Google::Protobuf::DoubleValue,
      }.freeze

      def cast_to_proto(type)
        if Protobuf::NUMERIC_TYPES.key?(type) || type.is_a?(Google::Protobuf::EnumDescriptor)
          @value
        elsif WRAPPER_DESCRIPTORS.key?(type)
          type.msgclass.new(value: @value)
        elsif type == Protobuf::ANY_DESCRIPTOR
          message = PREFERRED_PROTO_WRAPPER.fetch(@type).new(value: @value)
          Google::Protobuf::Any.pack(message)
        elsif type == Protobuf::VALUE_DESCRIPTOR
          Google::Protobuf::Value.from_ruby(@value)
        else
          raise EvaluateError, "Cannot convert #{self} to #{type.inspect}"
        end
      end
    end

    class Bool
      BOOL_DESCRIPTOR = Google::Protobuf::BoolValue.descriptor

      def cast_to_proto(type)
        case type
        when :bool
          @value
        when BOOL_DESCRIPTOR
          type.msgclass.new(value: @value)
        when Protobuf::ANY_DESCRIPTOR
          message = Google::Protobuf::BoolValue.new(value: @value)
          Google::Protobuf::Any.pack(message)
        when Protobuf::VALUE_DESCRIPTOR
          Google::Protobuf::Value.from_ruby(@value)
        else
          raise EvaluateError, "Cannot convert #{self} to #{type.inspect}"
        end
      end
    end

    class Null
      def cast_to_proto(type)
        case type
        when :int32 then 0
        when Google::Protobuf::EnumDescriptor then :NULL_VALUE
        when Protobuf::ANY_DESCRIPTOR
          message = cast_to_proto(Protobuf::VALUE_DESCRIPTOR)
          Google::Protobuf::Any.pack(message)
        when Protobuf::VALUE_DESCRIPTOR
          Google::Protobuf::Value.from_ruby(nil)
        when Protobuf::LIST_DESCRIPTOR
          raise EvaluateError, "Cannot convert null to ListValue"
        when Protobuf::STRUCT_DESCRIPTOR
          raise EvaluateError, "Cannot convert null to Struct"
        when Google::Protobuf::Descriptor
          # Any other message type should just be a null
          nil
        else
          raise EvaluateError, "Cannot convert #{self} to #{type.inspect}"
        end
      end
    end

    class String
      STRING_DESCRIPTOR = Google::Protobuf::StringValue.descriptor

      def cast_to_proto(type)
        case type
        when :string
          @value
        when STRING_DESCRIPTOR
          type.msgclass.new(value: @value)
        when Protobuf::ANY_DESCRIPTOR
          message = Google::Protobuf::StringValue.new(value: @value)
          Google::Protobuf::Any.pack(message)
        when Protobuf::VALUE_DESCRIPTOR
          Google::Protobuf::Value.from_ruby(@value)
        else
          raise EvaluateError, "Cannot convert #{self} to #{type.inspect}"
        end
      end
    end

    class Bytes
      BYTES_DESCRIPTOR = Google::Protobuf::BytesValue.descriptor

      def cast_to_proto(type)
        # Google::Protobuf expects byte fields to be simple strings
        str_value = @value.pack("C*")

        case type
        when :bytes
          str_value
        when BYTES_DESCRIPTOR
          type.msgclass.new(value: str_value)
        when Protobuf::ANY_DESCRIPTOR
          message = Google::Protobuf::BytesValue.new(value: str_value)
          Google::Protobuf::Any.pack(message)
        when Protobuf::VALUE_DESCRIPTOR
          # Canonical encoding of bytes for JSON is to base64 encode them
          Google::Protobuf::Value.from_ruby(Base64.strict_encode64(str_value))
        else
          raise EvaluateError, "Cannot convert #{self} to #{type.inspect}"
        end
      end
    end

    class List
      def cast_to_proto(type)
        case type
        when Protobuf::RepeatedType
          cast_type = type.type_descriptor || type.type
          @value.map { |v| v.cast_to_proto(cast_type) }
        when Protobuf::LIST_DESCRIPTOR
          list_value = Google::Protobuf::ListValue.new
          @value.each { |v| list_value.values << v.cast_to_proto(Protobuf::VALUE_DESCRIPTOR) }
          list_value
        when Protobuf::ANY_DESCRIPTOR
          Google::Protobuf::Any.pack(cast_to_proto(Protobuf::LIST_DESCRIPTOR))
        when Protobuf::VALUE_DESCRIPTOR
          Google::Protobuf::Value.new(list_value: cast_to_proto(Protobuf::LIST_DESCRIPTOR))
        else
          raise EvaluateError, "Cannot convert #{self} to #{type.inspect}"
        end
      end
    end

    class Map
      def cast_to_proto(type)
        case type
        when Protobuf::MapType
          cast_type = type.value_descriptor || type.value_type
          @value.to_h { |k, v| [k.cast_to_proto(:string), v.cast_to_proto(cast_type)] }
        when Protobuf::STRUCT_DESCRIPTOR
          struct_value = Google::Protobuf::Struct.new
          @value.each do |k, v|
            struct_value.fields[k.cast_to_proto(:string)] = v.cast_to_proto(Protobuf::VALUE_DESCRIPTOR)
          end
          struct_value
        when Protobuf::ANY_DESCRIPTOR
          Google::Protobuf::Any.pack(cast_to_proto(Protobuf::STRUCT_DESCRIPTOR))
        when Protobuf::VALUE_DESCRIPTOR
          Google::Protobuf::Value.new(struct_value: cast_to_proto(Protobuf::STRUCT_DESCRIPTOR))
        else
          raise EvaluateError, "Cannot convert #{self} to #{type.inspect}"
        end
      end
    end

    class Timestamp
      TIMESTAMP_DESCRIPTOR = Google::Protobuf::Timestamp.descriptor

      def cast_to_proto(type)
        case type
        when TIMESTAMP_DESCRIPTOR
          Google::Protobuf::Timestamp.from_time(@value)
        when Protobuf::ANY_DESCRIPTOR
          message = cast_to_proto(TIMESTAMP_DESCRIPTOR)
          Google::Protobuf::Any.pack(message)
        when Protobuf::VALUE_DESCRIPTOR
          # Canonical encoding of timestamps for JSON is a string
          Google::Protobuf::Value.from_ruby(@value.strftime("%Y-%m-%dT%H:%M:%S.%9NZ"))
        else
          raise EvaluateError, "Cannot convert #{self} to #{type.inspect}"
        end
      end
    end

    class Duration
      DURATION_DESCRIPTOR = Google::Protobuf::Duration.descriptor

      def cast_to_proto(type)
        case type
        when DURATION_DESCRIPTOR
          seconds, rest = @value.divmod(1)
          Google::Protobuf::Duration.new(
            seconds: seconds,
            nanos: (rest * 1_000_000_000).to_i
          )
        when Protobuf::ANY_DESCRIPTOR
          message = cast_to_proto(DURATION_DESCRIPTOR)
          Google::Protobuf::Any.pack(message)
        when Protobuf::VALUE_DESCRIPTOR
          # Canonical encoding of durations for JSON is a string with an "s"
          Google::Protobuf::Value.from_ruby("#{@value}s")
        else
          raise EvaluateError, "Cannot convert #{self} to #{type.inspect}"
        end
      end
    end

    module Types
      class Message
        def cast_to_proto(type)
          if type == @message.class.descriptor
            @message
          elsif type == Protobuf::ANY_DESCRIPTOR
            Google::Protobuf::Any.pack(message)
          elsif type == Protobuf::VALUE_DESCRIPTOR
            # Convert it to JSON and then decode that JSON
            Google::Protobuf::Value.decode_json(@message.to_json)
          else
            raise EvaluateError, "Cannot convert #{self} to #{type.inspect}"
          end
        end
      end
    end
  end
rescue LoadError
  # Protobuf support is optional
end

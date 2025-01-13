# frozen_string_literal: true

require "google/protobuf/struct_pb"
require "google/protobuf/wrappers_pb"
require "google/protobuf/any_pb"
require "google/protobuf/well_known_types"

module Cel
  # Wrapper type for protobuf messages
  class Message < Value
    extend FunctionBindings

    attr_reader :message

    # Automatically unwrap protobuf well known types
    def self.new(message)
      value = unwrap_well_known(message)
      return value if value

      super
    end

    # Create a new message type from a hash of Cel field values
    def self.from_cel_fields(descriptor, hash)
      klass = descriptor.msgclass
      message = klass.new
      hash.each do |field_name, value|
        fd = descriptor.lookup(field_name)
        proto_value = value.cast_to_proto(Cel::Protobuf.field_descriptor_type(fd))

        # Setting message fields to nil throws an exception, so we just do
        # nothing in that case
        next if fd.type == :message && proto_value.nil?

        if proto_value.is_a?(Array)
          fd.get(message).replace(proto_value)
        elsif proto_value.is_a?(Hash)
          map = fd.get(message)
          proto_value.each { |k, v| map[k] = v }
        else
          fd.set(message, proto_value)
        end
      end
      new(message)
    end

    def initialize(message)
      super(MessageType[message])
      @message = message
    end

    # Maps to the behavior of a test-only select
    def field_set?(key)
      fd = @message.class.descriptor.lookup(key)
      raise NoSuchFieldError.new(self, key) unless fd

      # Repeated fields (list or map) are set if non-empty
      fd_label = fd.label
      return Bool.new(fd.get(@message).size != 0) if fd_label == :repeated # rubocop:disable Style/ZeroLengthPredicate

      # Some fields have special presence checks. The "has_FIELD?" method
      # returns either false or 0 for true.
      has_method = :"has_#{key}?"
      return Bool.new(@message.public_send(has_method) != false) if @message.respond_to?(has_method)

      # Otherwise, it's considered unset if it's not the default. JRuby does
      # not support #default so the rest of the cases are for it.
      value = fd.get(@message)
      is_default =
        if fd.respond_to?(:default)
          value == fd.default
        elsif Cel::Protobuf::NUMERIC_TYPES.key?(fd.type)
          value.zero?
        elsif fd.type == :bool
          value == false
        elsif fd.type == :string || fd.type == :bytes # rubocop:disable Style/MultipleComparison
          value == ""
        elsif fd.type == :message
          value.nil?
        elsif fd.type == :enum
          Cel::Protobuf.enum_lookup_name(fd.subtype, value).zero?
        else
          raise EvaluateError, "Unexpected field descriptor type: #{fd.type}"
        end

      Bool.new(!is_default)
    end

    cel_func { global_function("[]", %i[message string], :any) }
    def [](key)
      fd = @message.class.descriptor.lookup(key)
      raise NoSuchFieldError.new(self, key) unless fd

      fd_type = Cel::Protobuf.field_descriptor_type(fd)
      value = fd.get(@message)
      Cel::Protobuf.proto_to_cel(value, fd_type)
    end

    def ==(other)
      other.is_a?(self.class) && @message == other.message
    end

    def to_ruby
      @message
    end

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

    # For well known types, returns the proper Cel type instead. Returns nil
    # if there is no well known type for the given message.
    def self.unwrap_well_known(message)
      case message
      when Google::Protobuf::Any
        klass = Google::Protobuf::DescriptorPool.generated_pool.lookup(message.type_name).msgclass
        new(klass.decode(message.value))
      when Google::Protobuf::ListValue
        elements = message.values.map { |v| unwrap_proto_value(v) }
        List.new(elements)
      when Google::Protobuf::Struct
        hash = message.fields.to_a.to_h { |k, v| [String.new(k), unwrap_proto_value(v)] }
        Map.new(hash)
      when Google::Protobuf::Value
        unwrap_proto_value(message)
      when Google::Protobuf::NullValue
        Null.new
      when Google::Protobuf::DoubleValue, Google::Protobuf::FloatValue
        Number.new(:double, message.value)
      when Google::Protobuf::Int64Value, Google::Protobuf::Int32Value
        Number.new(:int, message.value)
      when Google::Protobuf::UInt64Value, Google::Protobuf::UInt32Value
        Number.new(:uint, message.value)
      when Google::Protobuf::BoolValue
        Bool.new(message.value)
      when Google::Protobuf::StringValue
        String.new(message.value)
      when Google::Protobuf::BytesValue
        Bytes.new(message.value.b)
      when Google::Protobuf::Timestamp
        Timestamp.new(message.to_time)
      when Google::Protobuf::Duration
        Duration.new(message.seconds + (message.nanos / 1_000_000_000.0))
      end
    end

    # For Google::Protobuf::Value, returns the proper Cel type instead.
    def self.unwrap_proto_value(value)
      case value.kind
      when nil, :null_value then Null.new
      when :number_value then Number.new(:double, value.number_value)
      when :string_value then String.new(value.string_value)
      when :bool_value then Bool.new(value.bool_value)
      when :struct_value then unwrap_well_known(value.struct_value)
      when :list_value then unwrap_well_known(value.list_value)
      else
        raise EvaluateError, "Unexpected protobuf value kind: #{value.kind}"
      end
    end
  end
end

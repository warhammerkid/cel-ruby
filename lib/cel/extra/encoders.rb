# frozen_string_literal: true

require "base64"

module Cel
  module Extra
    module Encoders
      extend FunctionBindings

      cel_func { global_function("base64.encode", %i[bytes], :string) }
      def self.encode(bytes)
        String.new(Base64.strict_encode64(bytes.value))
      end

      cel_func { global_function("base64.decode", %i[string], :bytes) }
      def self.decode(string)
        Bytes.new(Base64.decode64(string.value))
      end
    end
  end
end

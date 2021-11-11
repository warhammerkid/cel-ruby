# frozen_string_literal: true

require_relative "../test_helper"
require "google/protobuf/well_known_types"

class CelProtobufCheckTest < Minitest::Test
  def test_literal_expression
    assert_equal environment.check("timestamp('2009-02-13T23:31:30Z')"), Google::Protobuf::Timestamp
    assert_equal environment.check("duration('123s')"), Google::Protobuf::Duration
    assert_equal environment.check("duration('123s').seconds"), :int
    assert_equal environment.check("google.protobuf.Durationgoogle.protobuf.Duration{seconds: 123}.seconds"), :int
  end

  def test_type_literal
    assert_equal environment.check("type(timestamp('2009-02-13T23:31:30Z'))"), Cel::TYPES[:type]
    assert_equal environment.check("type(duration('123s'))"), Cel::TYPES[:type]
  end

  private

  def environment(*args)
    Cel::Environment.new(*args)
  end
end

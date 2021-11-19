# frozen_string_literal: true

require_relative "../test_helper"
require "google/protobuf/well_known_types"

class CelProtobufEvaluateTest < Minitest::Test
  def test_literal_expression
    assert_equal environment.evaluate("timestamp('2009-02-13T23:31:30Z')"),
                 Google::Protobuf::Timestamp.new.from_time(Time.parse("2009-02-13T23:31:30Z"))
    assert_equal environment.evaluate("duration('123s')"), Google::Protobuf::Duration.new(seconds: 123)
    assert_equal environment.evaluate("duration('1s').seconds"), Cel::Number.new(:int, 1)
    assert_equal environment.evaluate("duration('1m').seconds"), Cel::Number.new(:int, 60)
    assert_equal environment.evaluate("duration('1h').seconds"), Cel::Number.new(:int, 60)
    assert_equal environment.evaluate("duration('1ms').nanos"), Cel::Number.new(:int, 1_000_000)
    assert_equal environment.evaluate("duration('1us').nanos"), Cel::Number.new(:int, 1000)
    assert_equal environment.evaluate("duration('1ns').nanos"), Cel::Number.new(:int, 1)
    assert_equal environment.evaluate("duration('0.5m').seconds"), Cel::Number.new(:int, 30)
    assert_equal environment.evaluate("google.protobuf.Duration{seconds: 123}.seconds"), Cel::Number.new(:int, 123)
    assert_equal environment.evaluate("duration.seconds", duration: Google::Protobuf::Duration.new(seconds: 123)),
                 Cel::Number.new(:int, 123)

    assert_raises(Cel::EvaluateError) { environment.evaluate("duration('1t').nanos") }
  end

  def test_type_literal
    assert_equal environment.evaluate("type(timestamp('2009-02-13T23:31:30Z'))"), Google::Protobuf::Timestamp
    assert_equal environment.evaluate("type(duration('123s'))"), Google::Protobuf::Duration
  end

  private

  def environment(*args)
    Cel::Environment.new(*args)
  end
end

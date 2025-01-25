# frozen_string_literal: true

require_relative "../test_helper"
require "cel/extra/encoders"

class CelExtraEncodersTest < Minitest::Test
  def test_encode
    assert_equal Cel::String.new("aGVsbG8="), evaluate("base64.encode(b'hello')")
    assert_raises(Cel::EvaluateError) { evaluate("base64.encode('hello')", check: false) }
  end

  def test_decode
    assert_equal Cel::Bytes.new("hello"), evaluate("base64.decode('aGVsbG8=')")
    assert_equal Cel::Bytes.new("hello"), evaluate("base64.decode('aGVsbG8')")
    assert_raises(Cel::EvaluateError) { evaluate("base64.decode(b'aGVsbG8=')", check: false) }
  end

  private

  def evaluate(expr, check: true)
    env = Cel::Environment.new
    env.extend_functions(Cel::Extra::Encoders)
    check ? env.evaluate(expr) : env.program(env.parse(expr)).evaluate
  end
end

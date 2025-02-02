# frozen_string_literal: true

require_relative "../test_helper"
require "cel/extra/formatting"

class CelExtraFormattingTest < Minitest::Test
  def test_basic_formatting
    assert_equal "no substitution", cel_format("no substitution")
    assert_equal "str is filler and some more", cel_format("str is %s and some more", "filler")
    assert_equal "% and also %", cel_format("%% and also %%")
    assert_equal "%text%", cel_format("%%%s%%", "text")
    assert_equal "percent on the right%", cel_format("percent on the right%%")
    assert_equal "%percent on the left", cel_format("%%percent on the left")
  end

  def test_string_format
    assert_equal "null: null", cel_format("null: %s", nil)
    assert_equal "999999999999", cel_format("%s", 999_999_999_999)
    assert_equal "some bytes: xyz", cel_format("some bytes: %s", Cel::Bytes.new("xyz"))
  end

  def test_decimal_format
    assert_equal "42", cel_format("%d", 42)
    assert_equal "uint(64)", cel_format("uint(%d)", Cel::Number.new(:uint, 64))
    assert_raises(Cel::EvaluateError) { cel_format("%d", 3.2) }
    assert_raises(Cel::EvaluateError) { cel_format("%d", nil) }
  end

  def test_float_format
    assert_equal "2.718280", cel_format("%f", 2.71828) # Check default precision
    assert_equal "1.234", cel_format("%.3f", 1.2345)
    assert_equal "NaN", cel_format("%f", "NaN")
    assert_equal "∞", cel_format("%f", "Infinity")
    assert_equal "-∞", cel_format("%f", "-Infinity")
    assert_raises(Cel::EvaluateError) { cel_format("%f", 42) }
    assert_raises(Cel::EvaluateError) { cel_format("%f", nil) }
  end

  def test_binary_format
    assert_equal "this is 5 in binary: 101", cel_format("this is 5 in binary: %b", 5)
    assert_equal "unsigned 64 in binary: 1000000", cel_format("unsigned 64 in binary: %b", 64)
    assert_equal "bit set from bool: 1", cel_format("bit set from bool: %b", true)
    assert_raises(Cel::EvaluateError) { cel_format("%b", nil) }
  end

  def test_hex_format
    assert_equal "1e is 20 in hexadecimal", cel_format("%x is 20 in hexadecimal", 30)
    assert_equal "1E is 20 in hexadecimal", cel_format("%X is 20 in hexadecimal", 30)
    assert_equal "1770 is 6000 in hexadecimal", cel_format("%X is 6000 in hexadecimal", Cel::Number.new(:uint, 6000))
    assert_equal "48656c6c6f20776f726c6421", cel_format("%x", "Hello world!")
    assert_equal "48656C6C6F20776F726C6421", cel_format("%X", "Hello world!")
    assert_equal "6279746520737472696e67", cel_format("%x", Cel::Bytes.new("byte string"))
    assert_equal "6279746520737472696E67", cel_format("%X", Cel::Bytes.new("byte string"))
    assert_raises(Cel::EvaluateError) { cel_format("%x", 2.5) }
    assert_raises(Cel::EvaluateError) { cel_format("%X", nil) }
  end

  def test_octal_format
    assert_equal "13", cel_format("%o", 11)
    assert_equal(
      "this is an unsigned octal: 177777",
      cel_format("this is an unsigned octal: %o", Cel::Number.new(:uint, 65_535))
    )
    assert_raises(Cel::EvaluateError) { cel_format("%o", 3.14) }
    assert_raises(Cel::EvaluateError) { cel_format("%o", nil) }
  end

  def test_checker
    assert_raises(Cel::Error) { cel_format("%d %d %d", [1, 2]) }
  end

  private

  def cel_format(string, *args)
    Cel::Extra::Formatting.new(string).call(Cel.to_value(args))
  end
end

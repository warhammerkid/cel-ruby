# frozen_string_literal: true

require_relative "test_helper"

class CelParserTest < Minitest::Test
  def test_token_parsing
    number_tokens.each do |input, expected|
      parser = Cel::Parser.new
      parser.tokenize(input)
      next_token = parser.next_token
      assert_equal expected, next_token
    end

    string_tokens.each do |input, expected|
      parser = Cel::Parser.new
      input = input.dup.force_encoding(Encoding::BINARY)
      parser.tokenize(input)
      assert_equal [:tSTRING, expected], parser.next_token
    end

    bytes_tokens.each do |input, expected|
      parser = Cel::Parser.new
      input = input.dup.force_encoding(Encoding::BINARY)
      parser.tokenize(input)
      assert_equal [:tBYTES, expected], parser.next_token
    end
  end

  def test_literal_operation
    parser = Cel::Parser.new
    assert_equal parser.parse("1 == 2"), ["==", 1, 2]
    assert_equal parser.parse("'hello' == 'world'"), ["==", "hello", "world"]
  end

  def test_expression_parsing
    parser = Cel::Parser.new
    # assert_equal "a", parser.parse("a")
    assert_equal parser.parse("[]"), []
    assert_equal parser.parse("[1]"), [1]
    assert_equal parser.parse("[1, 2, 3]"), [1, 2, 3]
    assert_equal parser.parse("[1, 2, 3, 4, 5.0]"), [1, 2, 3, 4, 5.0]
    assert_equal parser.parse("{a: 1, b: 2, c: 3}"), {a: 1, b: 2, c: 3}
  end

  def test_funcall
    assert_equal parser.parse("type(1)"), [:type, [1]]
  end

  private

  def parser
    Cel::Parser.new
  end

  def number_tokens
    [
      ["123", [:tINT, 123]],
      ["-123", [:tINT, -123]],
      ["12345", [:tINT, 12345]],
      ["1.2", [:tDOUBLE, 1.2]],
      ["1e2", [:tDOUBLE, 100.0]],
      ["-1.2e2", [:tDOUBLE, -120.0]],
      ["-12u", [:tUINT, 12]],
      ["0xa123", [:tINT, 41251]]
    ]
  end

  def string_tokens
    [
      [%(""), ""], # Empty string
      [%('""'), "\"\""], # String of two double-quote characters
      [%('''x''x'''), "x''x"], # String of four characters "x''x"
      [%("\\""), "\""], # String of one double-quote character
      [%("\\"), "\\"], # String of one backslash character
      [%(r"\\"), "\\\\"] # String of two backslash characters
    ]
  end

  def bytes_tokens
    [
      [%(b"abc"), [97, 98, 99]], # Byte sequence of 97, 98, 99
      [%(b"ÿ"), [195, 191]], # Sequence of bytes 195 and 191 (UTF-8 of ÿ)
      [%(b"\303\277"), [195, 191]], # Also sequence of bytes 195 and 191
      # [%Q{"\303\277"}, "Ã¿"], # String of "Ã¿" (code points 195, 191)
      # [%Q{"\377"}, "ÿ"], # String of "ÿ" (code point 255)
      [%(b"\377"), [255]], # Sequence of byte 255 (not UTF-8 of ÿ)
      # [%Q{"\xFF"}, "ÿ"], # String of "ÿ" (code point 255)
      [%(b"\xFF"), [255]] # Sequence of byte 255 (not UTF-8 of ÿ)
    ]
  end
end

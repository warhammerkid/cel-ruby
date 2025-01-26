# frozen_string_literal: true

require_relative "../test_helper"
require "cel/extra/strings"

class CelExtraStringsTest < Minitest::Test
  def test_char_at
    assert_value "o", evaluate("'tacocat'.charAt(3)")
    assert_value "", evaluate("'tacocat'.charAt(7)")
    assert_value "©", evaluate("'©αT'.charAt(0)")
    assert_value "α", evaluate("'©αT'.charAt(1)")
    assert_value "T", evaluate("'©αT'.charAt(2)")
    assert_raises(Cel::EvaluateError) { evaluate("'a'.charAt(-1)") }
    assert_raises(Cel::EvaluateError) { evaluate("'a'.charAt(2)") }
  end

  def test_index_of
    assert_value 0, evaluate("'tacocat'.indexOf('')")
    assert_value 1, evaluate("'tacocat'.indexOf('ac')")
    assert_value(-1, evaluate("'tacocat'.indexOf('none')"))
    assert_value 3, evaluate("'tacocat'.indexOf('', 3)")
    assert_value 5, evaluate("'tacocat'.indexOf('a', 3)")
    assert_value 5, evaluate("'tacocat'.indexOf('at', 3)")
    assert_value 2, evaluate("'ta©o©αT'.indexOf('©')")
    assert_value 4, evaluate("'ta©o©αT'.indexOf('©', 3)")
    assert_value 4, evaluate("'ta©o©αT'.indexOf('©αT', 3)")
    assert_value(-1, evaluate("'ta©o©αT'.indexOf('©α', 5)"))
    assert_value 2, evaluate("'ijk'.indexOf('k')")
    assert_value 0, evaluate("'hello wello'.indexOf('hello wello')")
    assert_value 7, evaluate("'hello wello'.indexOf('ello', 6)")
  end

  def test_last_index_of
    assert_value 7, evaluate("'tacocat'.lastIndexOf('')")
    assert_value 5, evaluate("'tacocat'.lastIndexOf('at')")
    assert_value(-1, evaluate("'tacocat'.lastIndexOf('none')"))
    assert_value 3, evaluate("'tacocat'.lastIndexOf('', 3)")
    assert_value 1, evaluate("'tacocat'.lastIndexOf('a', 3)")
    assert_value 4, evaluate("'ta©o©αT'.lastIndexOf('©')")
    assert_value 2, evaluate("'ta©o©αT'.lastIndexOf('©', 3)")
    assert_value 4, evaluate("'ta©o©αT'.lastIndexOf('©α', 4)")
    assert_value 1, evaluate("'hello wello'.lastIndexOf('ello', 6)")
    assert_value 0, evaluate("'hello wello'.lastIndexOf('hello wello')")
  end

  def test_lower_ascii
    assert_value "tacocat", evaluate("'TacoCat'.lowerAscii()")
    assert_value "tacocÆt", evaluate("'TacoCÆt'.lowerAscii()")
    assert_value "tacocÆt xii", evaluate("'TacoCÆt Xii'.lowerAscii()")
  end

  def test_replace
    assert_value "12 days 12 hours", evaluate("'12 days 12 hours'.replace('{0}', '2')")
    assert_value "2 days 2 hours", evaluate("'{0} days {0} hours'.replace('{0}', '2')")
    assert_value "2 days 23 hours", evaluate("'{0} days {0} hours'.replace('{0}', '2', 1).replace('{0}', '23')")
    assert_value "1 ©o©α taco", evaluate("'1 ©αT taco'.replace('αT', 'o©α')")
    assert_value "_h_e_l_l_o_ _h_e_l_l_o_", evaluate("'hello hello'.replace('', '_')")
    assert_value "ello ello", evaluate("'hello hello'.replace('h', '')")
  end

  def test_split
    assert_value %w[hello world], evaluate("'hello world'.split(' ')")
    assert_value [], evaluate("'hello world events!'.split(' ', 0)")
    assert_value ["hello world events!"], evaluate("'hello world events!'.split(' ', 1)")
    assert_value %w[o o o o], evaluate("'o©o©o©o'.split('©', -1)")
    assert_value ["1", "2", "", "3", "4", "", ""], evaluate("'1,2,,3,4,,'.split(',', -4)")
  end

  def test_substring
    assert_value "cat", evaluate("'tacocat'.substring(4)")
    assert_value "", evaluate("'tacocat'.substring(7)")
    assert_value "taco", evaluate("'tacocat'.substring(0, 4)")
    assert_value "", evaluate("'tacocat'.substring(4, 4)")
    assert_value "©o©α", evaluate("'ta©o©αT'.substring(2, 6)")
    assert_value "", evaluate("'ta©o©αT'.substring(7, 7)")
    assert_raises(Cel::EvaluateError) { evaluate("'tacocat'.substring(40)") }
    assert_raises(Cel::EvaluateError) { evaluate("'tacocat'.substring(-1)") }
    assert_raises(Cel::EvaluateError) { evaluate("'tacocat'.substring(1, 50)") }
    assert_raises(Cel::EvaluateError) { evaluate("'tacocat'.substring(49, 50)") }
    assert_raises(Cel::EvaluateError) { evaluate("'tacocat'.substring(4, 3)") }
  end

  def test_trim
    assert_value "text", evaluate(%q(' \f\n\r\t\vtext  '.trim()))
    assert_value "text", evaluate(%q('\u0085\u00a0\u1680text'.trim()))
    assert_value "text", evaluate(%q('text\u2000\u2001\u2002\u2003\u2004\u2004\u2006\u2007\u2008\u2009'.trim()))
    assert_value "text", evaluate(%q('\u200atext\u2028\u2029\u202F\u205F\u3000'.trim()))
    assert_value "\u180etext\u200b\u200c\u200d\u2060\ufeff",
                 evaluate(%q('\u180etext\u200b\u200c\u200d\u2060\ufeff'.trim()))
  end

  def test_upper_ascii
    assert_value "TACOCAT", evaluate("'tacoCat'.upperAscii()")
    assert_value "TACOCαT", evaluate("'tacoCαt'.upperAscii()")
  end

  def test_strings_quote
    assert_value '"first\nsecond"', evaluate(%q(strings.quote('first\nsecond')))
    assert_value '"bell\a"', evaluate(%q(strings.quote('bell\a')))
    assert_value '"backspace\b"', evaluate(%q(strings.quote('backspace\b')))
    assert_value '"formfeed\f"', evaluate(%q(strings.quote('formfeed\f')))
    assert_value '"carriage \r return"', evaluate(%q(strings.quote('carriage \r return')))
    assert_value '"horizontal tab\t"', evaluate(%q(strings.quote('horizontal tab\t')))
    assert_value '"vertical \v tab"', evaluate(%q(strings.quote('vertical \v tab')))
    assert_value '"double \\\\\\\\ slash"', evaluate('strings.quote("double \\\\\\\\ slash")')
    assert_value '"two escape sequences \a\n"', evaluate('strings.quote("two escape sequences \a\n")')
    assert_value '"verbatim"', evaluate('strings.quote("verbatim")')
    assert_value '"ends with \\\\"', evaluate('strings.quote("ends with \\\\")')
    assert_value '"\\\\ starts with"', evaluate('strings.quote("\\\\ starts with")')
    assert_value '"printable unicode😀"', evaluate('strings.quote("printable unicode😀")')
    assert_value '"mid string \\" quote"', evaluate('strings.quote("mid string \" quote")')
    assert_value '"single-quote with \"double quote\""', evaluate(%q(strings.quote('single-quote with "double quote"')))
    assert_value %q("size('ÿ')"), evaluate(%q(strings.quote("size('ÿ')")))
    assert_value %q("size('πέντε')"), evaluate(%q(strings.quote("size('πέντε')")))
    assert_value '"завтра"', evaluate('strings.quote("завтра")')
    assert_value '""', evaluate('strings.quote("")')
  end

  def test_join
    assert_value "xy", evaluate("['x', 'y'].join()")
    assert_value "x-y", evaluate("['x', 'y'].join('-')")
    assert_value "", evaluate("[].join()")
    assert_value "", evaluate("[].join('-')")
  end

  def test_reverse
    assert_value "smug", evaluate("'gums'.reverse()")
    assert_value "semordnilap", evaluate("'palindromes'.reverse()")
    assert_value "htimS nhoJ", evaluate("'John Smith'.reverse()")
    assert_value "txete081u", evaluate("'u180etext'.reverse()")
    assert_value "U+0062", evaluate("'2600+U'.reverse()")
    assert_value "\ufeff\u2060\u200d\u200c\u200b\u180e", evaluate(%q('\u180e\u200b\u200c\u200d\u2060\ufeff'.reverse()))
  end

  private

  def evaluate(expr, check: true)
    env = Cel::Environment.new
    env.extend_functions(Cel::Extra::Strings)
    check ? env.evaluate(expr) : env.program(env.parse(expr)).evaluate
  end
end

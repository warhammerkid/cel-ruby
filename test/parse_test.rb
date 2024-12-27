# frozen_string_literal: true

require_relative "test_helper"

module AstShorthand
  def self.s(operand, field, t: false)
    Cel::AST::Select.new(wrap_ruby_value(operand), field, test_only: t)
  end

  def self.c(function, *args)
    args = args.map { |a| wrap_ruby_value(a) }
    Cel::AST::Call.new(nil, function, args)
  end

  def self.tc(target, function, *args)
    args = args.map { |a| wrap_ruby_value(a) }
    Cel::AST::Call.new(wrap_ruby_value(target), function, args)
  end

  def self.uint(value)
    Cel::AST::Literal.new(:uint, value)
  end

  def self.b(bytes)
    Cel::AST::Literal.new(:bytes, bytes)
  end

  def self.struct(name, fields_hash = {})
    entries = fields_hash.map do |k, v|
      raise "Keys should be symbols" unless k.is_a?(Symbol)

      Cel::AST::Entry.new(k.to_s, wrap_ruby_value(v))
    end
    Cel::AST::CreateStruct.new(name, entries)
  end

  def self._(iter, iter_var, accu_init, loop_step, loop_condition, accu_var: nil, result: nil)
    raise "iter_var must be a symbol" unless iter_var.is_a?(Symbol)
    raise "accu_var must be a symbol" unless accu_var.nil? || accu_var.is_a?(Symbol)

    Cel::AST::Comprehension.new(
      iter_var: iter_var.to_s,
      iter_range: wrap_ruby_value(iter),
      accu_var: accu_var ? accu_var.to_s : Cel::Macro::ACCUMULATOR_NAME,
      accu_init: wrap_ruby_value(accu_init),
      loop_condition: wrap_ruby_value(loop_condition),
      loop_step: wrap_ruby_value(loop_step),
      result: result ? wrap_ruby_value(result) : accu
    )
  end

  def self.accu
    Cel::Macro.accu_ident
  end

  def self.wrap_ruby_value(value)
    case value
    when Cel::AST::Expr then value
    when Symbol then Cel::AST::Identifier.new(value.to_s)
    when NilClass then Cel::AST::Literal.new(:null, nil)
    when TrueClass, FalseClass then Cel::AST::Literal.new(:bool, value)
    when String then Cel::AST::Literal.new(:string, value)
    when Integer then Cel::AST::Literal.new(:int, value)
    when Float then Cel::AST::Literal.new(:double, value)
    when Array then Cel::AST::CreateList.new(value.map { |v| wrap_ruby_value(v) })
    when Hash
      entries = value.map do |k, v|
        Cel::AST::Entry.new(wrap_ruby_value(k), wrap_ruby_value(v))
      end
      Cel::AST::CreateStruct.new("", entries)
    else
      raise "Cannot automatically convert to AST: #{value.inspect}"
    end
  end
end

class CelParseTest < Minitest::Test
  def test_numeric_parsing
    assert_equal ast { 123 }, parse("123")
    assert_equal ast { -123 }, parse("-123")
    assert_equal ast { 123 }, parse("0x7b")
    assert_equal ast { -123 }, parse("-0x7B")
    assert_equal ast { uint(123) }, parse("123u")
    assert_equal ast { uint(123) }, parse("0x7BU")
    assert_equal ast { 1.2 }, parse("1.2")
    assert_equal ast { 100.0 }, parse("1e2")
  end

  def test_string_parsing
    assert_equal ast { "" }, parse(%("")) # Empty string
    assert_equal ast { "\"\"" }, parse(%('""')) # String of two double-quote characters
    assert_equal ast { "x''x" }, parse(%('''x''x''')) # String of four characters "x''x"
    assert_equal ast { "\"" }, parse(%("\\"")) # String of one double-quote character
    assert_equal ast { "\\" }, parse(%("\\\\")) # String of one backslash character
    assert_equal ast { "\\\\" }, parse(%(r"\\\\")) # String of two backslash characters
  end

  def test_bytes_parsing
    assert_equal ast { b([97, 98, 99]) }, parse(%(b"abc"))
    assert_equal ast { b([195, 191]) }, parse(%(b"ÿ"))
    assert_equal ast { b([195, 191]) }, parse(%(b"\303\277"))
    assert_equal ast { b([255]) }, parse(%(b"\377").b)
    assert_equal ast { b([255]) }, parse(%(b"\xFF").b)
  end

  def test_other_literals
    assert_equal ast { nil }, parse("null")
    assert_equal ast { true }, parse("true")
    assert_equal ast { false }, parse("false")
  end

  def test_lists
    assert_equal ast { [] }, parse("[]")
    assert_equal ast { [-1, true, "asdf"] }, parse("[-1, true, 'asdf', ]")
  end

  def test_maps
    assert_equal ast { {} }, parse("{}")
    assert_equal ast { { "k" => "v" } }, parse("{'k': 'v',}")
    assert_equal ast { { 12 => "v", uint(13) => "v" } }, parse("{12: 'v', 13u: 'v'}")
    assert_equal ast { { false => "v" } }, parse("{false: 'v'}")
  end

  def test_select_and_identifiers
    assert_equal ast { :a }, parse("a")
    assert_equal ast { :".a" }, parse(".a")
    assert_equal ast { s(s(:".a", "b"), "c") }, parse(".a.b.c")
  end

  def test_named_structs
    assert_equal ast { struct("Test") }, parse("Test{}")
    assert_equal ast { struct("a.b.c", { d: "e" }) }, parse("a.b.c{d: 'e',}")
  end

  def test_call_expressions
    assert_equal ast { c("dyn", -1) }, parse("dyn(-1)")
    assert_equal ast { tc({ "a" => "b" }, "size") }, parse("{'a':'b'}.size()")
    assert_equal ast { c("[]", { 0 => 1, 2 => 2, 5 => true }, 5) }, parse("{0:1,2:2,5:true}[5]")
    assert_equal ast { c("-", -4) }, parse("-(-4)")
    assert_equal ast { -4 }, parse("--(-4)")
    assert_equal ast { c("!", false) }, parse("!!!!!false")
    assert_equal ast { c("==", 1, 2) }, parse("1 == 2")
    assert_equal ast { c("+", 3, c("*", 5, 4)) }, parse("3 + 5 * 4")
  end

  def test_conditional_expressions
    assert_equal ast { c("&&", false, true) }, parse("false && true")
    assert_equal ast { c("||", 1, 3) }, parse("1 || 3")
    assert_equal ast { c("?:", true, "a", 3.5) }, parse("true ? 'a' : 3.5")
  end

  def test_reserved_indentifier_parsing
    assert_equal ast { s(:a, "const") }, parse("a.const")

    err = assert_raises(Cel::ParseError) { parse("break == 2") }
    assert_match(/invalid usage of the reserved word "break"/, err.message)
  end

  def test_error
    assert_raises(Cel::ParseError) { parse("< 1 2") }
  end

  def test_has_macro
    assert_equal ast { s({}, "a", t: true) }, parse("has({}.a)")
    assert_equal ast { s({ "a" => 1, "b" => 2 }, "a", t: true) }, parse("has({'a': 1, 'b': 2}.a)")
    assert_raises(Cel::ParseError) { parse("has(a)") }
  end

  def test_all_macro
    assert_equal(
      ast { _([], :e, true, c("&&", accu, c(">", :e, 0)), c("@not_strictly_false", accu)) },
      parse("[].all(e, e > 0)")
    )
    assert_equal(
      ast { _([1, 2, 3], :e, true, c("&&", accu, c(">", :e, 0)), c("@not_strictly_false", accu)) },
      parse("[1, 2, 3].all(e, e > 0)")
    )
  end

  private

  def parse(expr)
    Cel::Parser.new.parse(expr)
  end

  def ast(&block)
    res = AstShorthand.module_eval(&block)
    AstShorthand.wrap_ruby_value(res)
  end
end

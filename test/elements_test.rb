# frozen_string_literal: true

require_relative "test_helper"

class CelElementsTest < Minitest::Test
  # issue-2
  def test_string_literal_comparison
    assert_equal "hoge", Cel::String.new("hoge")
    refute_equal "hoge", Cel::String.new("hogehoge")
    assert_equal Cel::String.new("hoge"), "hoge"
    refute_equal Cel::String.new("hogehoge"), "hoge"
  end

  def test_to_ruby_type
    inst = Cel::String.new("bang")
    assert_equal "bang", inst.to_ruby_type
    assert_kind_of String, inst.to_ruby_type

    inst = Cel::Number.new(:int, 1)
    assert_equal 1, inst.to_ruby_type
    assert_kind_of Integer, inst.to_ruby_type

    inst = Cel::Number.new(:float, 1.1)
    assert_equal 1.1, inst.to_ruby_type
    assert_kind_of Float, inst.to_ruby_type

    inst = Cel::List.new([1, 2, 3])
    assert_equal [1, 2, 3], inst.to_ruby_type
    assert_kind_of Array, inst.to_ruby_type
    assert_kind_of Integer, inst.to_ruby_type[0]

    inst = Cel::Map.new({ "a" => 1, "b" => 2 })
    assert_equal({ "a" => 1, "b" => 2 }, inst.to_ruby_type)
    assert_kind_of Hash, inst.to_ruby_type
    assert_kind_of Integer, inst.to_ruby_type["a"]
  end
end

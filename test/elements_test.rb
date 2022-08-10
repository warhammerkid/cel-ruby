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
end

# frozen_string_literal: true

require_relative "test_helper"

class CelCheckTest < Minitest::Test
  def test_literal_expression
    assert_equal environment.check("1 == 2"), Cel::TYPES[:bool]
    assert_equal environment.check("'hello' == 'hello'"), Cel::TYPES[:bool]
    assert_equal environment.check("'hello' == 'world'"), Cel::TYPES[:bool]
    assert_equal environment.check("1 == 1 || 1 == 2 || 3 > 4"), Cel::TYPES[:bool]
    assert_equal environment.check("1 + 2"), Cel::TYPES[:int]
    assert_equal environment.check("1 - 2"), Cel::TYPES[:int]
    assert_equal environment.check("1 * 2"), Cel::TYPES[:int]
    assert_equal environment.check("1 / 2"), Cel::TYPES[:int]
    assert_equal environment.check("1 % 2"), Cel::TYPES[:int]
    assert_equal environment.check("!false"), Cel::TYPES[:bool]
    assert_equal environment.check("-123"), Cel::TYPES[:int]
    assert_equal environment.check("-1.2e2"), Cel::TYPES[:double]

    assert_kind_of Cel::ListType, environment.check("[1, 2]")
    assert_kind_of Cel::MapType, environment.check("{'a': 2}")

    assert_equal environment.check("[1, 2][0]"), Cel::TYPES[:int]
    assert_equal environment.check("{a: 2}.a"), Cel::TYPES[:int]

    assert_raises(Cel::CheckError) { environment.check("[1, 2][2]") }
    assert_raises(Cel::CheckError) { environment.check("!'bla'") }
    assert_raises(Cel::CheckError) { environment.check("-12u") }
    assert_raises(Cel::CheckError) { environment.check("-[1, 2, 3]") }
    assert_raises(Cel::CheckError) { environment.check("1 + 'a'") }
  end

  def test_type_literal
    assert_equal environment.check("type(1)"), Cel::TYPES[:type]
    assert_equal environment.check("type('a')"), Cel::TYPES[:type]
    assert_equal environment.check("type(1) == string"), Cel::TYPES[:bool]
    assert_equal environment.check("type(type(1)) == type(string)"), Cel::TYPES[:bool]
  end

  def test_dynamic_proto
    assert_equal environment.check("google.protobuf.BoolValue{value: true}"), Cel::TYPES[:bool]
    assert_equal environment.check("google.protobuf.DoubleValue{value: -1.5e3}"), Cel::TYPES[:double]
    assert_equal environment.check("google.protobuf.Int64Value{value: -123}"), Cel::TYPES[:int]
    assert_equal environment.check("google.protobuf.ListValue{values: [3.0, 'foo', null]}"), Cel::TYPES[:list]
    assert_equal environment.check("google.protobuf.BytesValue{value: b'foo\\123'}"), Cel::TYPES[:bytes]
    assert_equal environment.check("google.protobuf.StringValue{value: 'foo'}"), Cel::TYPES[:string]
    assert_equal environment.check("google.protobuf.Struct{fields: {'uno': 1.0, 'dos': 2.0}}"), Cel::TYPES[:map]

    assert_equal environment.check("google.protobuf.Value{number_value: 12}"), Cel::TYPES[:double]
    assert_equal environment.check("google.protobuf.Value{number_value: -1.5e3}"), Cel::TYPES[:double]
    assert_equal environment.check("google.protobuf.Value{string_value: 'bla'}"), Cel::TYPES[:string]
  end

  def test_type_aggregates
    list_type = environment.check("[1,2,3]")
    assert_kind_of Cel::ListType, list_type
    assert_equal list_type.element_type, :int
    ####
    list_type = environment.check("['a','b','c']")
    assert_kind_of Cel::ListType, list_type
    assert_equal list_type.element_type, :string
    ####
    list_type = environment.check("dyn([1, 'one'])")
    assert_kind_of Cel::ListType, list_type
    assert_equal list_type.element_type, :any
    ####
    map_type = environment.check("{'a': 1,'b': 2,'c': 3}")
    assert_kind_of Cel::MapType, map_type
    assert_equal map_type.element_type, :string
    ####
    map_type = environment.check("dyn({'a': 1,'b': 2, 2: 3})")
    assert_kind_of Cel::MapType, map_type
    assert_equal map_type.element_type, :any
  end

  def test_var_expression
    assert_equal environment.check("a + 2"), :any
    assert_equal environment.check("a == 2"), Cel::TYPES[:bool]
    assert_equal environment(name: :int).check("a == 2"), Cel::TYPES[:bool]
    assert_equal environment(a: :map).check("a.b"), Cel::TYPES[:any]
    assert_equal environment(a: :any).check("a"), Cel::TYPES[:any]
    assert_equal environment(a: :bool).check("a"), Cel::TYPES[:bool]
    assert_raises(Cel::CheckError) { environment(a: :blow).check("a") }
  end

  def test_condition
    assert_equal environment.check("true ? 1 : 2"), :int
    assert_equal environment.check("2 > 3 ? 1 : 'a'"), :any
  end

  def test_func_cast
    assert_equal environment.check("int(\"1\")"), :int
    assert_equal environment.check("uint(1)"), :uint
    assert_equal environment.check("double(1)"), :double
    assert_equal environment.check("string(1)"), :string
    assert_equal environment.check("bytes('a')"), :bytes
  end

  def test_func_string
    assert_equal environment.check("'helloworld'.contains('fuzz')"), :bool
    assert_equal environment.check("'helloworld'.endsWith('world')"), :bool
    assert_equal environment.check("'helloworld'.startsWith('world')"), :bool
    assert_equal environment.check("'helloworld'.matches('lowo')"), :bool

    assert_raises(Cel::CheckError) { environment.check("'helloworld'.matches(1)") }
  end

  def test_funcs
    assert_equal environment.check("size(\"helloworld\")"), :int
    assert_equal environment.check("matches('helloworld', 'lowo')"), :bool
    assert_equal environment.check("1 in [1, 2, 3]"), :bool
    assert_equal environment(arr: :list).check("size(arr)"), Cel::TYPES[:int]

    assert_raises(Cel::CheckError) { environment.check("matches('helloworld', 1)") }
  end

  def test_macros_map_filter
    assert_equal environment.check("[1, 2, 3].all(e, e > 0)"), :bool
    assert_equal environment.check("[1, 2, 3].exists(e, e < 0)"), :bool
    assert_equal environment.check("[1, 2, 3].exists_one(e, e < 0)"), :bool
    assert_equal environment.check("[1, 2, 3].filter(e, e < 0)"), :list
    assert_equal environment.check("[1, 2, 3].map(e, e + 1)"), :list
    assert_equal environment.check("{'a': 1, 'b': 2}.all(e, e.matches('a'))"), :bool
    assert_equal environment.check("{'a': 1, 'b': 2}.exists(e, e.matches('a'))"), :bool
    assert_equal environment.check("{'a': 1, 'b': 2}.exists_one(e, e.matches('a'))"), :bool
  end

  def test_the_mothership
    assert_equal(
      environment.check(<<-EXPR
  account.balance >= transaction.withdrawal
    || (account.overdraftProtection
    && account.overdraftLimit >= transaction.withdrawal  - account.balance)
    EXPR
                       ), Cel::TYPES[:bool]
    )

    #     assert_equal(
    #       environment.check(<<-EXPR
    # // Object construction
    # common.GeoPoint{ latitude: 10.0, longitude: -5.5 }
    #   EXPR
    #     ),  Cel::TYPES[:object]
    #   )
  end

  private

  def environment(*args)
    Cel::Environment.new(*args)
  end
end

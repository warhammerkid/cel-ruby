# frozen_string_literal: true

require_relative "test_helper"

class CelEvaluateTest < Minitest::Test
  def test_literal_expression
    assert_equal environment.evaluate("1"), 1
    assert_equal environment.evaluate("null"), nil
    assert_equal environment.evaluate("1 == 2"), false
    assert_equal environment.evaluate("'hello' == 'hello'"), true
    assert_equal environment.evaluate("'hello' == 'hellohello'"), false
    assert_equal environment.evaluate("'hello' == 'world'"), false
    assert_equal environment.evaluate("1 == 1 || 1 == 2 || 3 > 4"), true
    assert_equal environment.evaluate("2 == 1 || 1 == 2 || 3 > 4"), false
    assert_equal environment.evaluate("1 == 1 && 2 == 2 && 3 < 4"), true
    assert_equal environment.evaluate("1 == 1 && 2 == 2 && 3 > 4"), false
    assert_equal environment.evaluate("!false"), true
    assert_equal environment.evaluate("-123"), -123
    assert_equal environment.evaluate("-1.2e2"), -1.2e2

    assert_equal environment.evaluate("[1, 2] == [1, 2]"), true
    assert_equal environment.evaluate("[1, 2, 3] == [1, 2]"), false
    assert_equal environment.evaluate("{'a': 1} == {'a': 1}"), true
    assert_equal environment.evaluate("{'a': 2} == {'a': 2}"), true

    assert_equal environment.evaluate("[1, 2][0]"), 1
    assert_equal environment.evaluate("{a: 2}.a"), 2
    assert_equal environment.evaluate("{a: 2}").a, 2
    assert_equal environment.evaluate("{\"a\": 2}.a"), 2
    assert_equal environment.evaluate("{\"a\": 2}[\"a\"]"), 2
  end

  def test_timestamp_duration
    assert_equal environment.evaluate("timestamp('2022-12-25T00:00:00Z')"), Time.parse("2022-12-25T00:00:00Z")
    assert_equal environment.evaluate("duration('60s')"), Cel::Duration.new(seconds: 60)
    assert_equal environment.evaluate("timestamp('2022-12-25T00:00:00Z') + duration('60s')"),
                 Time.parse("2022-12-25T00:00:60Z")
    assert_equal environment.evaluate("duration('60s') + duration('60s')"), Cel::Duration.new(seconds: 120)
    assert_equal environment.evaluate("timestamp('2022-12-25T00:00:60Z') - timestamp('2022-12-25T00:00:00Z')"),
                 Cel::Duration.new(seconds: 60)
    assert_equal environment.evaluate("timestamp('2022-12-25T00:00:00Z') - duration('60s')"),
                 Time.parse("2022-12-24T23:59:00Z")
    assert_equal environment.evaluate("timestamp('2022-12-25T00:00:00Z') < timestamp('2022-12-25T00:00:00Z')"), false

    assert_equal environment.evaluate("timestamp('2022-12-25T00:00:00Z').getDate()"), 25
    assert_equal environment.evaluate("timestamp('2022-12-25T00:00:00Z').getDayOfMonth()"), 24
    assert_equal environment.evaluate("timestamp('2022-12-25T00:00:00Z').getDayOfWeek()"), 0
    assert_equal environment.evaluate("timestamp('2022-12-25T00:00:00Z').getDayOfYear()"), 358
    assert_equal environment.evaluate("timestamp('2022-12-25T00:00:00Z').getFullYear()"), 2022
    assert_equal environment.evaluate("timestamp('2022-12-25T10:00:00Z').getHours()"), 10
    assert_equal environment.evaluate("timestamp('2022-12-25T00:10:00Z').getMinutes()"), 10
    assert_equal environment.evaluate("timestamp('2022-12-25T00:00:10Z').getSeconds()"), 10
    assert_equal environment.evaluate("timestamp('2022-12-25T00:00:10.1234567Z').getMilliseconds()"), 123
    assert_equal environment.evaluate("int(timestamp('2022-12-25T00:00:00Z'))"), 1_671_926_400
    assert_equal environment.evaluate("duration('3600s10ms').getHours()"), 1
    assert_equal environment.evaluate("duration('60s10ms').getMinutes()"), 1
    assert_equal environment.evaluate("duration('60s10ms').getSeconds()"), 60
    assert_equal environment.evaluate("duration('60s10ms').getMilliseconds()"), 10
  end

  def test_type_literal
    # assert_equal environment.evaluate("type(1)"), :int
    # assert_equal environment.evaluate("type(true)"), :bool
    assert_equal environment.evaluate("type(null)"), :null_type
    assert_equal environment.evaluate("type('a')"), :string
    assert_equal environment.evaluate("type(1) == string"), false
    assert_equal environment.evaluate("type(type(1)) == type(string)"), true
    assert_equal environment.evaluate("type(timestamp('2022-12-25T00:00:00Z'))"), :timestamp
  end

  def test_dynamic_proto
    # assert_equal environment.evaluate("google.protobuf.BoolValue{value: true}"), true
    # assert_equal environment.evaluate("google.protobuf.BytesValue{value: b'foo\\123'}"), "foo\123"
    # assert_equal environment.evaluate("google.protobuf.DoubleValue{value: -1.5e3}"), -1500.0
    # assert_equal environment.evaluate("google.protobuf.FloatValue{value: -1.5e3}"), -1500.0
    # assert_equal environment.evaluate("google.protobuf.Int32Value{value: -123}"), -123
    # assert_equal environment.evaluate("google.protobuf.Int64Value{value: -123}"), -123
    # assert_equal environment.evaluate("google.protobuf.Int32Value{}"), 0
    # assert_equal environment.evaluate("google.protobuf.NullValue{}"), nil
    # assert_equal environment.evaluate("google.protobuf.StringValue{value: 'foo'}"), "foo"
    # assert_equal environment.evaluate("google.protobuf.StringValue{}"), ""
    # assert_equal environment.evaluate("google.protobuf.Uint32Value{value: 123u}"), 123
    # assert_equal environment.evaluate("google.protobuf.Uint64Value{value: 123u}"), 123
    # assert_equal environment.evaluate("google.protobuf.ListValue{values: [3.0, 'foo', null]}"), [3.0, "foo", nil]
    # assert_equal environment.evaluate("google.protobuf.Struct{fields: {'uno': 1.0, 'dos': 2.0}}"),
    #              { "uno" => 1.0, "dos" => 2.0 }

    # assert_equal environment.evaluate("google.protobuf.Value{}"), nil
    # assert_equal environment.evaluate("google.protobuf.Value{null_value: NullValue.NULL_VALUE}"), nil
    # assert_equal environment.evaluate("google.protobuf.Value{number_value: 12}"), 12.0
    # assert_equal environment.evaluate("google.protobuf.Value{number_value: -1.5e3}"), -1500.0
    # assert_equal environment.evaluate("google.protobuf.Value{string_value: 'bla'}"), "bla"
    # assert_equal environment.evaluate("google.protobuf.Value{bool_value: true}"), true
    assert_equal environment.evaluate("google.protobuf.Timestamp{seconds: 946702800}"), Time.at(946_702_800)
    assert_equal environment.evaluate("google.protobuf.Duration{seconds: 60}"), Cel::Duration.new(60)
  end

  def test_var_expression
    assert_raises(Cel::EvaluateError) { environment.evaluate("a == 2") }
    assert_equal environment.evaluate("a == 2", { a: Cel::Number.new(:int, 1) }), false
  end

  def test_condition
    assert_equal environment.evaluate("true ? 1 : 2"), 1
    assert_equal environment.evaluate("2 < 3 ? 1 : 'a'"), 1
    assert_equal environment.evaluate("2 > 3 ? 1 : 'a'"), "a"
    assert_equal environment.evaluate("2 < 3 ? (2 + 3) : 'a'"), 5
  end

  def test_macros_has
    assert_equal environment.evaluate("has({a: 1, b: 2}.a)"), true
    assert_raises(Cel::NoSuchFieldError) { environment.evaluate("has(Struc{fields: {a: 1, b: 2}}.c)") }
    assert_equal environment.evaluate("has({'a': 1, 'b': 2}.a)"), true
    assert_equal environment.evaluate("has({'a': 1, 'b': 2}.c)"), false

    assert_raises(Cel::EvaluateError) { environment.evaluate("has(1.c)") }
  end

  def test_macros_map_filter
    assert_equal environment.evaluate("[1, 2, 3].all(e, e > 0)"), true
    assert_equal environment.evaluate("[1, 2, 3].all(e, e < 0)"), false
    assert_equal environment.evaluate("[1, 2, 3].exists(e, e < 3)"), true
    assert_equal environment.evaluate("[1, 2, 3].exists_one(e, e < 3)"), false
    assert_equal environment.evaluate("[1, 2, 3].filter(e, e < 2)"), [1]
    assert_equal environment.evaluate("[1, 2, 3].map(e, e + 1)"), [2, 3, 4]
    assert_equal environment.evaluate("{'a': 1, 'b': 2}.all(e, e.matches('a'))"), false
    assert_equal environment.evaluate("{'a': 1, 'b': 2}.exists(e, e.matches('a'))"), true
    assert_equal environment.evaluate("{'a': 1, 'b': 2}.exists_one(e, e.matches('a'))"), true
    # dyn
    assert_equal environment.evaluate("dyn([1, 2, 3]).map(e, e + e)"), [2, 4, 6]
    assert_equal environment.evaluate("dyn(['a', 'b', 'c']).map(e, e + e)"), %w[aa bb cc]
    assert_equal environment.evaluate("dyn([1, 'a']).map(e, e + e)"), [2, "aa"]
  end

  def test_func_size
    assert_equal environment.evaluate("size(\"helloworld\")"), 10
    assert_equal environment.evaluate("size(b\"\303\277\")"), 2
    assert_equal environment.evaluate("size([1, 2, 3])"), 3
    assert_equal environment.evaluate("size(['ab', 'cd', 'de'])"), 3
    assert_equal environment.evaluate("size({'a': 1, 'b': 2, 'cd': 3})"), 3
  end

  def test_func_cast
    assert_equal environment.evaluate("int(\"1\")"), 1
    assert_equal environment.evaluate("uint(1)"), 1
    assert_equal environment.evaluate("double(1)"), 1.0
    assert_equal environment.evaluate("string(1)"), "1"
    assert_equal environment.evaluate("bytes('a')"), [97]
  end

  def test_func_matches
    assert_equal environment.evaluate("matches('helloworld', 'lowo')"), true
    assert_equal environment.evaluate("matches('helloworld', '[a-z]+')"), true
    assert_equal environment.evaluate("matches('helloworld', 'fuzz')"), false
    assert_equal environment.evaluate("matches('helloworld', '[0-9]+')"), false
  end

  def test_func_in
    assert_equal environment.evaluate("1 in [1, 2, 3]"), true
    assert_equal environment.evaluate("1 in [2, 3, 4]"), false
    assert_equal environment.evaluate("'a' in {'a': 1, 'b': 2, 'cd': 3}"), true
    assert_equal environment.evaluate("'c' in {'a': 1, 'b': 2, 'cd': 3}"), false
  end

  def test_func_string
    assert_equal environment.evaluate("'helloworld'.contains('hello')"), true
    assert_equal environment.evaluate("'helloworld'.contains('fuzz')"), false
    assert_equal environment.evaluate("'helloworld'.endsWith('world')"), true
    assert_equal environment.evaluate("'helloworld'.endsWith('hello')"), false
    assert_equal environment.evaluate("'helloworld'.startsWith('hello')"), true
    assert_equal environment.evaluate("'helloworld'.startsWith('world')"), false
    assert_equal environment.evaluate("'helloworld'.matches('lowo')"), true
    assert_equal environment.evaluate("'helloworld'.matches('[a-z]+')"), true
    assert_equal environment.evaluate("'helloworld'.matches('fuzz')"), false
    assert_equal environment.evaluate("'helloworld'.matches('[0-9]+')"), false
  end

  def test_bindings
    assert_equal environment.evaluate("a", { a: nil }), nil
    assert_equal environment.evaluate("a", { a: true }), true
    assert_equal environment.evaluate("a", { a: 2 }), 2
    assert_equal environment.evaluate("a", { a: 1.2 }), 1.2
    assert_equal environment.evaluate("a", { a: "a" }), "a"
    assert_equal environment.evaluate("a[0]", { a: [1, 2, 3] }), 1
    assert_equal environment.evaluate("a", { a: [1, 2, 3] }), [1, 2, 3]
    assert_equal environment.evaluate("a.b", { a: { "b" => 2 } }), 2
    assert_equal environment.evaluate("a", { a: { "b" => 2 } }), { "b" => 2 }

    assert_raises(Cel::BindingError) { environment.evaluate("a", { a: Object.new }) }
  end

  def test_the_mothership
    program = environment.program(<<-EXPR
      account.balance >= transaction.withdrawal
        || (account.overdraftProtection
        && account.overdraftLimit >= transaction.withdrawal  - account.balance)
    EXPR
                                 )

    assert_equal program.evaluate(
      account: { balance: 100, overdraftProtection: false, overdraftLimit: 10 },
      transaction: { withdrawal: 10 }
    ), true
    assert_equal program.evaluate(
      account: { balance: 100, overdraftProtection: false, overdraftLimit: 10 },
      transaction: { withdrawal: 100 }
    ), true
    assert_equal program.evaluate(
      account: { balance: 100, overdraftProtection: false, overdraftLimit: 10 },
      transaction: { withdrawal: 101 }
    ), false
    assert_equal program.evaluate(
      account: { balance: 100, overdraftProtection: true, overdraftLimit: 10 },
      transaction: { withdrawal: 110 }
    ), true
    assert_equal program.evaluate(
      account: { balance: 100, overdraftProtection: true, overdraftLimit: 10 },
      transaction: { withdrawal: 111 }
    ), false
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

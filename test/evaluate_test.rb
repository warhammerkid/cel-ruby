# frozen_string_literal: true

require_relative "test_helper"

class CelEvaluateTest < Minitest::Test
  def test_literal_expression
    assert_equal 1, environment.evaluate("1").value
    assert_nil environment.evaluate("null").value
    assert_equal 4, environment.evaluate("2 + 2").value
    assert_equal 0, environment.evaluate("2 - 2").value
    assert_equal 4, environment.evaluate("2 * 2").value
    assert_equal 1, environment.evaluate("2 / 2").value
    assert_equal false, environment.evaluate("1 == 2").value
    assert_equal true, environment.evaluate("1 != 2").value
    assert_equal true, environment.evaluate("1 < 3").value
    assert_equal true, environment.evaluate("3 > 1").value
    assert_equal true, environment.evaluate("1 <= 3").value
    assert_equal true, environment.evaluate("3 >= 1").value
    assert_equal true, environment.evaluate("'hello' == 'hello'").value
    assert_equal false, environment.evaluate("'hello' == 'hellohello'").value
    assert_equal false, environment.evaluate("'hello' == 'world'").value
    assert_equal true, environment.evaluate("1 == 1 || 1 == 2 || 3 > 4").value
    assert_equal false, environment.evaluate("2 == 1 || 1 == 2 || 3 > 4").value
    assert_equal true, environment.evaluate("1 == 1 && 2 == 2 && 3 < 4").value
    assert_equal false, environment.evaluate("1 == 1 && 2 == 2 && 3 > 4").value
    assert_equal true, environment.evaluate("!false").value
    assert_equal(-123, environment.evaluate("-123").value)
    assert_equal(-1.2e2, environment.evaluate("-1.2e2").value)

    assert_equal true, environment.evaluate("[1, 2] == [1, 2]").value
    assert_equal false, environment.evaluate("[1, 2, 3] == [1, 2]").value
    assert_equal true, environment.evaluate("{'a': 1} == {'a': 1}").value
    assert_equal true, environment.evaluate("{'a': 2} == {'a': 2}").value

    assert_equal 1, environment.evaluate("[1, 2][0]").value
    assert_equal 2, environment.evaluate("{a: 2}.a").value
    assert_equal 2, environment.evaluate("{a: 2}").a
    assert_equal 2, environment.evaluate("{\"a\": 2}.a").value
    assert_equal 2, environment.evaluate("{\"a\": 2}[\"a\"]").value
  end

  def test_timestamp_duration
    assert_equal Time.parse("2022-12-25T00:00:00Z"), environment.evaluate("timestamp('2022-12-25T00:00:00Z')")
    assert_equal Cel::Duration.new(seconds: 60), environment.evaluate("duration('60s')")
    assert_equal Time.parse("2022-12-25T00:00:60Z"),
                 environment.evaluate("timestamp('2022-12-25T00:00:00Z') + duration('60s')")

    assert_equal Cel::Duration.new(seconds: 120), environment.evaluate("duration('60s') + duration('60s')")
    assert_equal Cel::Duration.new(seconds: 60),
                 environment.evaluate("timestamp('2022-12-25T00:00:60Z') - timestamp('2022-12-25T00:00:00Z')")

    assert_equal Time.parse("2022-12-24T23:59:00Z"),
                 environment.evaluate("timestamp('2022-12-25T00:00:00Z') - duration('60s')")

    assert_equal false,
                 environment.evaluate("timestamp('2022-12-25T00:00:00Z') < timestamp('2022-12-25T00:00:00Z')").value

    assert_equal 25, environment.evaluate("timestamp('2022-12-25T00:00:00Z').getDate()")
    assert_equal 24, environment.evaluate("timestamp('2022-12-25T00:00:00Z').getDayOfMonth()")
    assert_equal 0, environment.evaluate("timestamp('2022-12-25T00:00:00Z').getDayOfWeek()")
    assert_equal 358, environment.evaluate("timestamp('2022-12-25T00:00:00Z').getDayOfYear()")
    assert_equal 2022, environment.evaluate("timestamp('2022-12-25T00:00:00Z').getFullYear()")
    assert_equal 10, environment.evaluate("timestamp('2022-12-25T10:00:00Z').getHours()")
    assert_equal 10, environment.evaluate("timestamp('2022-12-25T00:10:00Z').getMinutes()")
    assert_equal 10, environment.evaluate("timestamp('2022-12-25T00:00:10Z').getSeconds()")
    assert_equal 123, environment.evaluate("timestamp('2022-12-25T00:00:10.1234567Z').getMilliseconds()")
    assert_equal 1_671_926_400, environment.evaluate("int(timestamp('2022-12-25T00:00:00Z'))")
    assert_equal 1, environment.evaluate("duration('3600s10ms').getHours()")
    assert_equal 1, environment.evaluate("duration('60s10ms').getMinutes()")
    assert_equal 60, environment.evaluate("duration('60s10ms').getSeconds()")
    assert_equal 10, environment.evaluate("duration('60s10ms').getMilliseconds()")
  end

  def test_type_literal
    assert_equal Cel::TYPES[:int], environment.evaluate("type(1)")
    assert_equal Cel::TYPES[:bool], environment.evaluate("type(true)")
    assert_equal Cel::TYPES[:null_type], environment.evaluate("type(null)")
    assert_equal Cel::TYPES[:string], environment.evaluate("type('a')")
    assert_equal false, environment.evaluate("type(1) == string").value
    assert_equal true, environment.evaluate("type(type(1)) == type(string)").value
    assert_equal Cel::TYPES[:timestamp], environment.evaluate("type(timestamp('2022-12-25T00:00:00Z'))")
  end

  def test_dynamic_proto
    assert_equal true, environment.evaluate("google.protobuf.BoolValue{value: true}").value
    assert_equal "foo".bytes, environment.evaluate("google.protobuf.BytesValue{value: b'foo'}")
    assert_equal(-1500.0, environment.evaluate("google.protobuf.DoubleValue{value: -1.5e3}"))
    assert_equal(-1500.0, environment.evaluate("google.protobuf.FloatValue{value: -1.5e3}"))
    assert_equal(-123, environment.evaluate("google.protobuf.Int32Value{value: -123}"))
    assert_equal(-123, environment.evaluate("google.protobuf.Int64Value{value: -123}"))
    assert_equal 0, environment.evaluate("google.protobuf.Int32Value{}")
    assert_nil environment.evaluate("google.protobuf.NullValue{}").value
    assert_equal "foo", environment.evaluate("google.protobuf.StringValue{value: 'foo'}")
    assert_equal "", environment.evaluate("google.protobuf.StringValue{}")
    assert_equal 123, environment.evaluate("google.protobuf.UInt32Value{value: 123u}")
    assert_equal 123, environment.evaluate("google.protobuf.UInt64Value{value: 123u}")
    assert_equal [3.0, "foo", nil], environment.evaluate("google.protobuf.ListValue{values: [3.0, 'foo', null]}")
    assert_equal({ "uno" => 1.0, "dos" => 2.0 },
                 environment.evaluate("google.protobuf.Struct{fields: {'uno': 1.0, 'dos': 2.0}}"))

    assert_nil environment.evaluate("google.protobuf.Value{}").value
    assert_nil environment.evaluate("google.protobuf.Value{null_value: NullValue.NULL_VALUE}").value
    assert_equal 12.0, environment.evaluate("google.protobuf.Value{number_value: 12}")
    assert_equal(-1500.0, environment.evaluate("google.protobuf.Value{number_value: -1.5e3}"))
    assert_equal "bla", environment.evaluate("google.protobuf.Value{string_value: 'bla'}")
    assert_equal true, environment.evaluate("google.protobuf.Value{bool_value: true}").value
    assert_equal({ "a" => 1.0, "b" => "two" },
                 environment.evaluate("google.protobuf.Value{struct_value: {'a': 1.0, 'b': 'two'}}"))
    assert_equal Time.at(946_702_800), environment.evaluate("google.protobuf.Timestamp{seconds: 946702800}")
    assert_equal Cel::Duration.new(60), environment.evaluate("google.protobuf.Duration{seconds: 60}")
    assert_equal 12, environment.evaluate(
      "google.protobuf.Any{" \
      "type_url: 'type.googleapis.com/google.protobuf.Value', " \
      "value: b'\x11\x00\x00\x00\x00\x00\x00(@'}"
    )
  end

  def test_var_expression
    assert_raises(Cel::EvaluateError) { environment.evaluate("a == 2") }
    assert_equal false, environment.evaluate("a == 2", { a: Cel::Number.new(:int, 1) }).value
    assert_equal [1, 2, 3], environment(a: :list).evaluate("a", { a: [1, 2, 3] })

    assert_equal Time.parse("2022-12-25T00:00:00Z"),
                 environment(a: :timestamp).evaluate("a", { a: "2022-12-25T00:00:00Z" })

    assert_equal Time.parse("2022-12-25T00:00:00Z"),
                 environment(a: :timestamp).evaluate("a", { a: Time.parse("2022-12-25T00:00:00Z") })

    assert_equal Time.parse("2022-12-25T00:00:00Z"), environment(a: :timestamp).evaluate("a", { a: 1_671_926_400 })
    assert_equal Time.parse("2022-12-25T00:00:00Z"), environment(a: :timestamp)
      .evaluate("a", { a: Google::Protobuf::Timestamp.new(seconds: 1_671_926_400) })
  end

  def test_condition
    assert_equal 1, environment.evaluate("true ? 1 : 2")
    assert_equal 1, environment.evaluate("2 < 3 ? 1 : 'a'")
    assert_equal "a", environment.evaluate("2 > 3 ? 1 : 'a'")
    assert_equal 5, environment.evaluate("2 < 3 ? (2 + 3) : 'a'")
    assert_equal "a", environment.evaluate("(3 < 2 || 4 < 2) ? (2 + 3) : 'a'")
  end

  def test_macros_has
    assert_equal true, environment.evaluate("has({a: 1, b: 2}.a)").value
    assert_raises(Cel::NoSuchFieldError) { environment.evaluate("has(Struc{fields: {a: 1, b: 2}}.c)") }
    assert_equal true, environment.evaluate("has({'a': 1, 'b': 2}.a)").value
    assert_equal false, environment.evaluate("has({'a': 1, 'b': 2}.c)").value

    assert_raises(Cel::EvaluateError) { environment.evaluate("has(1.c)") }
  end

  def test_macros_map_filter
    assert_equal true, environment.evaluate("[1, 2, 3].all(e, e > 0)").value
    assert_equal false, environment.evaluate("[1, 2, 3].all(e, e < 0)").value
    assert_equal true, environment.evaluate("[1, 2, 3].exists(e, e < 3)").value
    assert_equal false, environment.evaluate("[1, 2, 3].exists_one(e, e < 3)").value
    assert_equal [1], environment.evaluate("[1, 2, 3].filter(e, e < 2)")
    assert_equal [2, 3, 4], environment.evaluate("[1, 2, 3].map(e, e + 1)")
    assert_equal false, environment.evaluate("{'a': 1, 'b': 2}.all(e, e.matches('a'))").value
    assert_equal true, environment.evaluate("{'a': 1, 'b': 2}.exists(e, e.matches('a'))").value
    assert_equal true, environment.evaluate("{'a': 1, 'b': 2}.exists_one(e, e.matches('a'))").value
    # dyn
    assert_equal [2, 4, 6], environment.evaluate("dyn([1, 2, 3]).map(e, e + e)")
    assert_equal %w[aa bb cc], environment.evaluate("dyn(['a', 'b', 'c']).map(e, e + e)")
    assert_equal [2, "aa"], environment.evaluate("dyn([1, 'a']).map(e, e + e)")
  end

  def test_func_size
    assert_equal 10, environment.evaluate("size(\"helloworld\")")
    assert_equal 2, environment.evaluate("size(b\"\303\277\")")
    assert_equal 3, environment.evaluate("size([1, 2, 3])")
    assert_equal 3, environment.evaluate("size(['ab', 'cd', 'de'])")
    assert_equal 3, environment.evaluate("size({'a': 1, 'b': 2, 'cd': 3})")
  end

  def test_func_cast
    assert_equal 1, environment.evaluate("int(\"1\")")
    assert_equal 1, environment.evaluate("uint(1)")
    assert_equal 1.0, environment.evaluate("double(1)")
    assert_equal "1", environment.evaluate("string(1)")
    assert_equal [97], environment.evaluate("bytes('a')")
  end

  def test_func_matches
    assert_equal true, environment.evaluate("matches('helloworld', 'lowo')").value
    assert_equal true, environment.evaluate("matches('helloworld', '[a-z]+')").value
    assert_equal false, environment.evaluate("matches('helloworld', 'fuzz')").value
    assert_equal false, environment.evaluate("matches('helloworld', '[0-9]+')").value
  end

  def test_func_in
    assert_equal true, environment.evaluate("1 in [1, 2, 3]").value
    assert_equal false, environment.evaluate("1 in [2, 3, 4]").value
    assert_equal true, environment.evaluate("'a' in {'a': 1, 'b': 2, 'cd': 3}").value
    assert_equal false, environment.evaluate("'c' in {'a': 1, 'b': 2, 'cd': 3}").value
  end

  def test_func_string
    assert_equal true, environment.evaluate("'helloworld'.contains('hello')").value
    assert_equal false, environment.evaluate("'helloworld'.contains('fuzz')").value
    assert_equal true, environment.evaluate("'helloworld'.endsWith('world')").value
    assert_equal false, environment.evaluate("'helloworld'.endsWith('hello')").value
    assert_equal true, environment.evaluate("'helloworld'.startsWith('hello')").value
    assert_equal false, environment.evaluate("'helloworld'.startsWith('world')").value
    assert_equal true, environment.evaluate("'helloworld'.matches('lowo')").value
    assert_equal true, environment.evaluate("'helloworld'.matches('[a-z]+')").value
    assert_equal false, environment.evaluate("'helloworld'.matches('fuzz')").value
    assert_equal false, environment.evaluate("'helloworld'.matches('[0-9]+')").value
  end

  def test_custom_funcs
    assert_equal(4, environment(foo: Cel::Function(:int, :int, return_type: :int) do |a, b|
                                       a + b
                                     end).evaluate("foo(2, 2)"))
    assert_equal(4, environment(foo: Cel::Function(:int, :int) { |a, b| a + b }).evaluate("foo(2, 2)"))
    assert_equal(4, environment(foo: Cel::Function() { |a, b| a + b }).evaluate("foo(2, 2)"))
    assert_equal(12, environment(foo: Cel::Function(:int, :int) do |a, b|
                                        a + b
                                      end).evaluate("foo(size(\"helloworld\"), 2)"))
    assert_equal(4, environment(foo: ->(a, b) { a + b }).evaluate("foo(2, 2)"))
    assert_equal([2], environment(intersect: Cel::Function(:list, :list, return_type: :list) do |a, b|
                                               a & b
                                             end).evaluate("intersect([1,2], [2])"))
  end

  def test_bindings
    assert_nil environment.evaluate("a", { a: nil }).value
    assert_equal true, environment.evaluate("a", { a: true }).value
    assert_equal 2, environment.evaluate("a", { a: 2 })
    assert_equal 1.2, environment.evaluate("a", { a: 1.2 })
    assert_equal "a", environment.evaluate("a", { a: "a" })
    assert_equal 1, environment.evaluate("a[0]", { a: [1, 2, 3] })
    assert_equal [1, 2, 3], environment.evaluate("a", { a: [1, 2, 3] })
    assert_equal 2, environment.evaluate("a.b", { a: { "b" => 2 } })
    assert_equal({ "b" => 2 }, environment.evaluate("a", { a: { "b" => 2 } }))

    assert_raises(Cel::BindingError) { environment.evaluate("a", { a: Object.new }) }
  end

  def test_the_mothership
    program = environment.program(<<-EXPR
      account.balance >= transaction.withdrawal
        || (account.overdraftProtection
        && account.overdraftLimit >= transaction.withdrawal  - account.balance)
    EXPR
                                 )

    assert_equal true, program.evaluate(
      account: { balance: 100, overdraftProtection: false, overdraftLimit: 10 },
      transaction: { withdrawal: 10 }
    ).value
    assert_equal true, program.evaluate(
      account: { balance: 100, overdraftProtection: false, overdraftLimit: 10 },
      transaction: { withdrawal: 100 }
    ).value
    assert_equal false, program.evaluate(
      account: { balance: 100, overdraftProtection: false, overdraftLimit: 10 },
      transaction: { withdrawal: 101 }
    ).value
    assert_equal true, program.evaluate(
      account: { balance: 100, overdraftProtection: true, overdraftLimit: 10 },
      transaction: { withdrawal: 110 }
    ).value
    assert_equal false, program.evaluate(
      account: { balance: 100, overdraftProtection: true, overdraftLimit: 10 },
      transaction: { withdrawal: 111 }
    ).value
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

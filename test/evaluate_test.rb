# frozen_string_literal: true

require_relative "test_helper"
require_relative "test_pb"

class CelEvaluateTest < Minitest::Test
  def test_literal_expression
    assert_value 1, environment.evaluate("1")
    assert_nil_value environment.evaluate("null")
    assert_value 4, environment.evaluate("2 + 2")
    assert_value 0, environment.evaluate("2 - 2")
    assert_value 4, environment.evaluate("2 * 2")
    assert_value 1, environment.evaluate("2 / 2")
    assert_value false, environment.evaluate("1 == 2")
    assert_value true, environment.evaluate("1 != 2")
    assert_value true, environment.evaluate("1 < 3")
    assert_value true, environment.evaluate("3 > 1")
    assert_value true, environment.evaluate("1 <= 3")
    assert_value true, environment.evaluate("3 >= 1")
    assert_value true, environment.evaluate("'hello' == 'hello'")
    assert_value false, environment.evaluate("'hello' == 'hellohello'")
    assert_value false, environment.evaluate("'hello' == 'world'")
    assert_value true, environment.evaluate("1 == 1 || 1 == 2 || 3 > 4")
    assert_value false, environment.evaluate("2 == 1 || 1 == 2 || 3 > 4")
    assert_value true, environment.evaluate("1 == 1 && 2 == 2 && 3 < 4")
    assert_value false, environment.evaluate("1 == 1 && 2 == 2 && 3 > 4")
    assert_value true, environment.evaluate("!false")
    assert_value(-123, environment.evaluate("-123"))
    assert_value(-1.2e2, environment.evaluate("-1.2e2"))

    assert_value true, environment.evaluate("[1, 2] == [1, 2]")
    assert_value false, environment.evaluate("[1, 2, 3] == [1, 2]")
    assert_value true, environment.evaluate("{'a': 1} == {'a': 1}")
    assert_value true, environment.evaluate("{'a': 2} == {'a': 2}")

    assert_value 1, environment.evaluate("[1, 2][0]")
    assert_value 2, environment.evaluate("{\"a\": 2}.a")
    assert_value 2, environment.evaluate("{\"a\": 2}[\"a\"]")
  end

  def test_timestamp_duration
    assert_value Time.parse("2022-12-25T00:00:00Z"), environment.evaluate("timestamp('2022-12-25T00:00:00Z')")
    assert_value Cel::Duration.new(60), environment.evaluate("duration('60s')")
    assert_value Time.parse("2022-12-25T00:00:60Z"),
                 environment.evaluate("timestamp('2022-12-25T00:00:00Z') + duration('60s')")

    assert_value Cel::Duration.new(120), environment.evaluate("duration('60s') + duration('60s')")
    assert_value Cel::Duration.new(60),
                 environment.evaluate("timestamp('2022-12-25T00:00:60Z') - timestamp('2022-12-25T00:00:00Z')")

    assert_value Time.parse("2022-12-24T23:59:00Z"),
                 environment.evaluate("timestamp('2022-12-25T00:00:00Z') - duration('60s')")

    assert_value false,
                 environment.evaluate("timestamp('2022-12-25T00:00:00Z') < timestamp('2022-12-25T00:00:00Z')")

    assert_value 25, environment.evaluate("timestamp('2022-12-25T00:00:00Z').getDate()")
    assert_value 24, environment.evaluate("timestamp('2022-12-25T00:00:00Z').getDayOfMonth()")
    assert_value 0, environment.evaluate("timestamp('2022-12-25T00:00:00Z').getDayOfWeek()")
    assert_value 358, environment.evaluate("timestamp('2022-12-25T00:00:00Z').getDayOfYear()")
    assert_value 2022, environment.evaluate("timestamp('2022-12-25T00:00:00Z').getFullYear()")
    assert_value 10, environment.evaluate("timestamp('2022-12-25T10:00:00Z').getHours()")
    assert_value 10, environment.evaluate("timestamp('2022-12-25T00:10:00Z').getMinutes()")
    assert_value 10, environment.evaluate("timestamp('2022-12-25T00:00:10Z').getSeconds()")
    assert_value 123, environment.evaluate("timestamp('2022-12-25T00:00:10.1234567Z').getMilliseconds()")
    assert_value 1_671_926_400, environment.evaluate("int(timestamp('2022-12-25T00:00:00Z'))")
    assert_value 1, environment.evaluate("duration('3600s10ms').getHours()")
    assert_value 1, environment.evaluate("duration('60s10ms').getMinutes()")
    assert_value 60, environment.evaluate("duration('60s10ms').getSeconds()")
    assert_value 10, environment.evaluate("duration('60s10ms').getMilliseconds()")
  end

  def test_type_literal
    assert_equal Cel::TYPES[:int], environment.evaluate("type(1)")
    assert_equal Cel::TYPES[:bool], environment.evaluate("type(true)")
    assert_equal Cel::TYPES[:null_type], environment.evaluate("type(null)")
    assert_equal Cel::TYPES[:string], environment.evaluate("type('a')")
    assert_value false, environment.evaluate("type(1) == string")
    assert_value true, environment.evaluate("type(type(1)) == type(string)")
    assert_equal Cel::TYPES[:timestamp], environment.evaluate("type(timestamp('2022-12-25T00:00:00Z'))")
  end

  def test_dynamic_proto
    assert_value true, environment.evaluate("google.protobuf.BoolValue{value: true}")
    assert_value "foo".b, environment.evaluate("google.protobuf.BytesValue{value: b'foo'}")
    assert_value(-1500.0, environment.evaluate("google.protobuf.DoubleValue{value: -1.5e3}"))
    assert_value(-1500.0, environment.evaluate("google.protobuf.FloatValue{value: -1.5e3}"))
    assert_value(-123, environment.evaluate("google.protobuf.Int32Value{value: -123}"))
    assert_value(-123, environment.evaluate("google.protobuf.Int64Value{value: -123}"))
    assert_value 0, environment.evaluate("google.protobuf.Int32Value{}")
    assert_value "foo", environment.evaluate("google.protobuf.StringValue{value: 'foo'}")
    assert_value "", environment.evaluate("google.protobuf.StringValue{}")
    assert_value 123, environment.evaluate("google.protobuf.UInt32Value{value: 123u}")
    assert_value 123, environment.evaluate("google.protobuf.UInt64Value{value: 123u}")
    assert_value [3.0, "foo", nil], environment.evaluate("google.protobuf.ListValue{values: [3.0, 'foo', null]}")
    assert_value({ "uno" => 1.0, "dos" => 2.0 },
                 environment.evaluate("google.protobuf.Struct{fields: {'uno': 1.0, 'dos': 2.0}}"))

    assert_nil_value environment.evaluate("google.protobuf.Value{}")
    assert_nil_value environment.evaluate("google.protobuf.Value{null_value: google.protobuf.NullValue.NULL_VALUE}")
    assert_value 12.0, environment.evaluate("google.protobuf.Value{number_value: 12}")
    assert_value(-1500.0, environment.evaluate("google.protobuf.Value{number_value: -1.5e3}"))
    assert_value "bla", environment.evaluate("google.protobuf.Value{string_value: 'bla'}")
    assert_value true, environment.evaluate("google.protobuf.Value{bool_value: true}")
    assert_value({ "a" => 1.0, "b" => "two" },
                 environment.evaluate("google.protobuf.Value{struct_value: {'a': 1.0, 'b': 'two'}}"))
    assert_value Time.at(946_702_800), environment.evaluate("google.protobuf.Timestamp{seconds: 946702800}")
    assert_value Cel::Duration.new(60), environment.evaluate("google.protobuf.Duration{seconds: 60}")
    assert_value 12, environment.evaluate(
      "google.protobuf.Any{" \
      "type_url: 'type.googleapis.com/google.protobuf.Value', " \
      "value: b'\x11\x00\x00\x00\x00\x00\x00(@'}"
    )
  end

  def test_user_proto
    # Has macro
    assert_value true, environment.evaluate("has(cel.ruby.test.TestStruct{a: 1}.a)")
    assert_raises(Cel::NoSuchFieldError) { environment.evaluate("has(cel.ruby.test.TestStruct{}.c)") }

    # Container override
    container = Cel::Container.new("cel.ruby.test")
    assert_value 2, environment(nil, container).evaluate("TestStruct{b: 2}.b")

    # Binding protos
    decs = { s: :any }
    binds = { s: Cel::Ruby::Test::TestStruct.new(a: 3, b: 2) }
    assert_value true, environment(decs, container).evaluate("s == TestStruct{a: 3, b: 2}", binds)
  end

  def test_enum_proto
    assert_value 0, environment.evaluate("google.protobuf.NullValue.NULL_VALUE")

    container = Cel::Container.new("google.protobuf")
    assert_value 0, environment(nil, container).evaluate("NullValue.NULL_VALUE")
  end

  def test_var_expression
    assert_raises(Cel::EvaluateError) { environment.evaluate("a == 2") }
    assert_value false, environment.evaluate("a == 2", { a: Cel::Number.new(:int, 1) })
    assert_value [1, 2, 3], environment(a: :list).evaluate("a", { a: [1, 2, 3] })

    assert_value Time.parse("2022-12-25T00:00:00Z"), environment(a: :timestamp)
      .evaluate("a", { a: Google::Protobuf::Timestamp.new(seconds: 1_671_926_400) })
  end

  def test_condition
    assert_value 1, environment.evaluate("true ? 1 : 2")
    assert_value 1, environment.evaluate("2 < 3 ? 1 : 'a'")
    assert_value "a", environment.evaluate("2 > 3 ? 1 : 'a'")
    assert_value 5, environment.evaluate("2 < 3 ? (2 + 3) : 'a'")
    assert_value "a", environment.evaluate("(3 < 2 || 4 < 2) ? (2 + 3) : 'a'")
  end

  def test_macros_has
    assert_value true, environment.evaluate("has({'a': 1, 'b': 2}.a)")
    assert_value false, environment.evaluate("has({'a': 1, 'b': 2}.c)")

    assert_raises(Cel::EvaluateError) { environment.evaluate("has(1.c)") }
  end

  def test_macros_comprehensions
    assert_value true, environment.evaluate("[1, 2, 3].all(e, e > 0)")
    assert_value false, environment.evaluate("[1, 2, 3].all(e, e < 0)")
    assert_value true, environment.evaluate("[1, 2, 3].exists(e, e < 3)")
    assert_value false, environment.evaluate("[1, 2, 3].exists_one(e, e < 3)")
    assert_value [1], environment.evaluate("[1, 2, 3].filter(e, e < 2)")
    assert_value [2, 3, 4], environment.evaluate("[1, 2, 3].map(e, e + 1)")
    assert_value false, environment.evaluate("{'a': 1, 'b': 2}.all(e, e.matches('a'))")
    assert_value true, environment.evaluate("{'a': 1, 'b': 2}.exists(e, e.matches('a'))")
    assert_value true, environment.evaluate("{'a': 1, 'b': 2}.exists_one(e, e.matches('a'))")
    # dyn
    assert_value [2, 4, 6], environment.evaluate("dyn([1, 2, 3]).map(e, e + e)")
    assert_value %w[aa bb cc], environment.evaluate("dyn(['a', 'b', 'c']).map(e, e + e)")
    assert_value [2, "aa"], environment.evaluate("dyn([1, 'a']).map(e, e + e)")
  end

  def test_func_size
    assert_value 10, environment.evaluate("size(\"helloworld\")")
    assert_value 2, environment.evaluate("size(b\"\303\277\")")
    assert_value 3, environment.evaluate("size([1, 2, 3])")
    assert_value 3, environment.evaluate("size(['ab', 'cd', 'de'])")
    assert_value 3, environment.evaluate("size({'a': 1, 'b': 2, 'cd': 3})")
  end

  def test_func_cast
    assert_value 1, environment.evaluate("int(\"1\")")
    assert_value 1, environment.evaluate("uint(1)")
    assert_value 1.0, environment.evaluate("double(1)")
    assert_value "1", environment.evaluate("string(1)")
    assert_value "a".b, environment.evaluate("bytes('a')")
  end

  def test_func_matches
    assert_value true, environment.evaluate("matches('helloworld', 'lowo')")
    assert_value true, environment.evaluate("matches('helloworld', '[a-z]+')")
    assert_value false, environment.evaluate("matches('helloworld', 'fuzz')")
    assert_value false, environment.evaluate("matches('helloworld', '[0-9]+')")
  end

  def test_func_in
    assert_value true, environment.evaluate("1 in [1, 2, 3]")
    assert_value false, environment.evaluate("1 in [2, 3, 4]")
    assert_value true, environment.evaluate("'a' in {'a': 1, 'b': 2, 'cd': 3}")
    assert_value false, environment.evaluate("'c' in {'a': 1, 'b': 2, 'cd': 3}")
  end

  def test_func_string
    assert_value true, environment.evaluate("'helloworld'.contains('hello')")
    assert_value false, environment.evaluate("'helloworld'.contains('fuzz')")
    assert_value true, environment.evaluate("'helloworld'.endsWith('world')")
    assert_value false, environment.evaluate("'helloworld'.endsWith('hello')")
    assert_value true, environment.evaluate("'helloworld'.startsWith('hello')")
    assert_value false, environment.evaluate("'helloworld'.startsWith('world')")
    assert_value true, environment.evaluate("'helloworld'.matches('lowo')")
    assert_value true, environment.evaluate("'helloworld'.matches('[a-z]+')")
    assert_value false, environment.evaluate("'helloworld'.matches('fuzz')")
    assert_value false, environment.evaluate("'helloworld'.matches('[0-9]+')")
  end

  def test_custom_funcs
    assert_value(4, environment(foo: Cel::Function(:int, :int, return_type: :int) do |a, b|
                                       a + b
                                     end).evaluate("foo(2, 2)"))
    assert_value(4, environment(foo: Cel::Function(:int, :int) { |a, b| a + b }).evaluate("foo(2, 2)"))
    assert_value(4, environment(foo: Cel::Function() { |a, b| a + b }).evaluate("foo(2, 2)"))
    assert_value(12, environment(foo: Cel::Function(:int, :int) do |a, b|
                                        a + b
                                      end).evaluate("foo(size(\"helloworld\"), 2)"))
    assert_value(4, environment(foo: ->(a, b) { a + b }).evaluate("foo(2, 2)"))
    assert_value([2], environment(intersect: Cel::Function(:list, :list, return_type: :list) do |a, b|
                                               a & b
                                             end).evaluate("intersect([1,2], [2])"))
  end

  def test_extend_functions
    my_module = Module.new do
      extend Cel::FunctionBindings

      cel_func { global_function("foo", %i[int int], :int) }
      def self.foo(a, b)
        Cel::Number.new(:int, a.value + b.value)
      end
    end
    my_singleton_module = Module.new do
      class << self
        extend Cel::FunctionBindings

        cel_func { global_function("bah.too.foo", %i[int int], :int) }
        def foo(a, b)
          Cel::Number.new(:int, a.value + b.value)
        end
      end
    end
    env = Cel::Environment.new
    env.extend_functions(my_module)
    env.extend_functions(my_singleton_module)

    assert_value(4, env.evaluate("foo(2, 2)"))
    assert_value(4, env.evaluate("bah.too.foo(2, 2)"))
  end

  def test_bindings
    assert_nil_value environment.evaluate("a", { a: nil })
    assert_value true, environment.evaluate("a", { a: true })
    assert_value 2, environment.evaluate("a", { a: 2 })
    assert_value 1.2, environment.evaluate("a", { a: 1.2 })
    assert_value "a", environment.evaluate("a", { a: "a" })
    assert_value 1, environment.evaluate("a[0]", { a: [1, 2, 3] })
    assert_value [1, 2, 3], environment.evaluate("a", { a: [1, 2, 3] })
    assert_value 2, environment.evaluate("a.b", { a: { "b" => 2 } })
    assert_value 3, environment.evaluate("a.b.c.d", { "a.b.c.d" => 3 })
    assert_value({ "b" => 2 }, environment.evaluate("a", { a: { "b" => 2 } }))

    assert_raises(Cel::BindingError) { environment.evaluate("a", { a: Object.new }) }
  end

  def test_the_mothership
    program = environment.program(<<-EXPR
      account.balance >= transaction.withdrawal
        || (account.overdraftProtection
        && account.overdraftLimit >= transaction.withdrawal  - account.balance)
    EXPR
                                 )

    assert_value true, program.evaluate(
      account: { balance: 100, overdraftProtection: false, overdraftLimit: 10 },
      transaction: { withdrawal: 10 }
    )
    assert_value true, program.evaluate(
      account: { balance: 100, overdraftProtection: false, overdraftLimit: 10 },
      transaction: { withdrawal: 100 }
    )
    assert_value false, program.evaluate(
      account: { balance: 100, overdraftProtection: false, overdraftLimit: 10 },
      transaction: { withdrawal: 101 }
    )
    assert_value true, program.evaluate(
      account: { balance: 100, overdraftProtection: true, overdraftLimit: 10 },
      transaction: { withdrawal: 110 }
    )
    assert_value false, program.evaluate(
      account: { balance: 100, overdraftProtection: true, overdraftLimit: 10 },
      transaction: { withdrawal: 111 }
    )
  end

  private

  def environment(*args)
    Cel::Environment.new(*args)
  end
end

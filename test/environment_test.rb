# frozen_string_literal: true

require_relative "test_helper"

class CelEnvironmentTest < Minitest::Test
  def test_check_literal_expression
    assert_equal environment.check("1 == 2"), Cel::TYPES[:bool]
    assert_equal environment.check("'hello' == 'hello'"), Cel::TYPES[:bool]
    assert_equal environment.check("'hello' == 'world'"), Cel::TYPES[:bool]
    assert_equal environment.check("1 == 1 || 1 == 2 || 3 > 4"), Cel::TYPES[:bool]
    assert_equal environment.check("1 + 2"), Cel::TYPES[:int]

    assert_kind_of Cel::ListType, environment.check("[1, 2]")
    assert_kind_of Cel::MapType, environment.check("{'a': 2}")

    assert_equal environment.check("[1, 2][0]"), Cel::TYPES[:int]
    assert_equal environment.check("Struct{a: 2}.a"), Cel::TYPES[:int]
  end

  def test_check_type_literal
    assert_equal environment.check("type(1)"), Cel::TYPES[:type]
    assert_equal environment.check("type('a')"), Cel::TYPES[:type]
    assert_equal environment.check("type(1) == string"), Cel::TYPES[:bool]
    assert_equal environment.check("type(type(1)) == type(string)"), Cel::TYPES[:bool]
  end

  def test_check_type_aggregates
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

  def test_check_var_expression
    assert_equal environment.check("a + 2"), :any
    assert_equal environment.check("a == 2"), Cel::TYPES[:bool]
    assert_equal environment(name: :int).check("a == 2"), Cel::TYPES[:bool]
  end

  def test_check_condition
    assert_equal environment.check("true ? 1 : 2"), :int
    assert_equal environment.check("2 > 3 ? 1 : 'a'"), :any
  end

  def test_check_func_cast
    assert_equal environment.check("int(\"1\")"), :int
    assert_equal environment.check("uint(1)"), :uint
    assert_equal environment.check("double(1)"), :double
    assert_equal environment.check("string(1)"), :string
    assert_equal environment.check("bytes('a')"), :bytes
  end

  def test_check_func_string
    assert_equal environment.check("'helloworld'.contains('fuzz')"), :bool
    assert_equal environment.check("'helloworld'.endsWith('world')"), :bool
    assert_equal environment.check("'helloworld'.startsWith('world')"), :bool
    assert_equal environment.check("'helloworld'.matches('lowo')"), :bool
  end

  def test_check_funcs
    assert_equal environment.check("size(\"helloworld\")"), :int
    assert_equal environment.check("matches('helloworld', 'lowo')"), :bool
    assert_equal environment.check("1 in [1, 2, 3]"), :bool
  end

  def test_check_macros_map_filter
    assert_equal environment.check("[1, 2, 3].all(e, e > 0)"), :bool
    assert_equal environment.check("[1, 2, 3].exists(e, e < 0)"), :bool
    assert_equal environment.check("[1, 2, 3].exists_one(e, e < 0)"), :bool
    assert_equal environment.check("[1, 2, 3].filter(e, e < 0)"), :list
    assert_equal environment.check("[1, 2, 3].map(e, e + 1)"), :list
    assert_equal environment.check("{'a': 1, 'b': 2}.all(e, e.matches('a'))"), :bool
    assert_equal environment.check("{'a': 1, 'b': 2}.exists(e, e.matches('a'))"), :bool
    assert_equal environment.check("{'a': 1, 'b': 2}.exists_one(e, e.matches('a'))"), :bool
  end

  def test_evaluate_literal_expression
    assert_equal environment.evaluate("1 == 2"), false
    assert_equal environment.evaluate("'hello' == 'hello'"), true
    assert_equal environment.evaluate("'hello' == 'world'"), false
    assert_equal environment.evaluate("1 == 1 || 1 == 2 || 3 > 4"), true
    assert_equal environment.evaluate("2 == 1 || 1 == 2 || 3 > 4"), false
    assert_equal environment.evaluate("1 == 1 && 2 == 2 && 3 < 4"), true
    assert_equal environment.evaluate("1 == 1 && 2 == 2 && 3 > 4"), false
    assert_equal environment.evaluate("!false"), true

    assert_equal environment.evaluate("[1, 2] == [1, 2]"), true
    assert_equal environment.evaluate("[1, 2, 3] == [1, 2]"), false
    assert_equal environment.evaluate("{'a': 1} == {'a': 1}"), true
    assert_equal environment.evaluate("{'a': 2} == {'a': 2}"), true

    assert_equal environment.evaluate("[1, 2][0]"), 1
    assert_equal environment.evaluate("Struct{a: 2}.a"), 2
    assert_equal environment.evaluate("{\"a\": 2}.a"), 2
    assert_equal environment.evaluate("{\"a\": 2}[\"a\"]"), 2
  end

  def test_evaluate_type_literal
    assert_equal environment.evaluate("type(1)"), :int
    assert_equal environment.evaluate("type('a')"), :string
    assert_equal environment.evaluate("type(1) == string"), false
    assert_equal environment.evaluate("type(type(1)) == type(string)"), true
  end

  def test_evaluate_var_expression
    assert_raises(Cel::Error) { environment.evaluate("a == 2") }
    assert_equal environment.evaluate("a == 2", { a: Cel::Number.new(:int, 1) }), false
  end

  def test_evaluate_condition
    assert_equal environment.evaluate("true ? 1 : 2"), 1
    assert_equal environment.evaluate("2 < 3 ? 1 : 'a'"), 1
    assert_equal environment.evaluate("2 > 3 ? 1 : 'a'"), "a"
    assert_equal environment.evaluate("2 < 3 ? (2 + 3) : 'a'"), 5
  end

  def test_evaluate_macros_has
    assert_equal environment.evaluate("has(Struct{a: 1, b: 2}.a)"), true
    assert_raises(Cel::NoSuchFieldError) { environment.evaluate("has(Struct{a: 1, b: 2}.c)") }
    assert_equal environment.evaluate("has({'a': 1, 'b': 2}.a)"), true
    assert_equal environment.evaluate("has({'a': 1, 'b': 2}.c)"), false
  end

  def test_evaluate_macros_map_filter
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

  def test_evaluate_func_size
    assert_equal environment.evaluate("size(\"helloworld\")"), 10
    assert_equal environment.evaluate("size(b\"\303\277\")"), 2
    assert_equal environment.evaluate("size([1, 2, 3])"), 3
    assert_equal environment.evaluate("size(['ab', 'cd', 'de'])"), 3
    assert_equal environment.evaluate("size({'a': 1, 'b': 2, 'cd': 3})"), 3
  end

  def test_evaluate_func_cast
    assert_equal environment.evaluate("int(\"1\")"), 1
    assert_equal environment.evaluate("uint(1)"), 1
    assert_equal environment.evaluate("double(1)"), 1.0
    assert_equal environment.evaluate("string(1)"), "1"
    assert_equal environment.evaluate("bytes('a')"), [97]
  end

  def test_evaluate_func_matches
    assert_equal environment.evaluate("matches('helloworld', 'lowo')"), true
    assert_equal environment.evaluate("matches('helloworld', '[a-z]+')"), true
    assert_equal environment.evaluate("matches('helloworld', 'fuzz')"), false
    assert_equal environment.evaluate("matches('helloworld', '[0-9]+')"), false
  end

  def test_evaluate_func_in
    assert_equal environment.evaluate("1 in [1, 2, 3]"), true
    assert_equal environment.evaluate("1 in [2, 3, 4]"), false
    assert_equal environment.evaluate("'a' in {'a': 1, 'b': 2, 'cd': 3}"), true
    assert_equal environment.evaluate("'c' in {'a': 1, 'b': 2, 'cd': 3}"), false
  end

  def test_evaluate_func_string
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

  def test_check_the_mothership
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

  def test_evaluate_the_mothership
    program = environment.program(<<-EXPR
      account.balance >= transaction.withdrawal
        || (account.overdraftProtection
        && account.overdraftLimit >= transaction.withdrawal  - account.balance)
    EXPR
                                 )

    assert_equal program.evaluate(
      account: Cel::Map.new(balance: 100, overdraftProtection: false, overdraftLimit: 10),
      transaction: Cel::Map.new(withdrawal: 10)
    ), true
    assert_equal program.evaluate(
      account: Cel::Map.new(balance: 100, overdraftProtection: false, overdraftLimit: 10),
      transaction: Cel::Map.new(withdrawal: 100)
    ), true
    assert_equal program.evaluate(
      account: Cel::Map.new(balance: 100, overdraftProtection: false, overdraftLimit: 10),
      transaction: Cel::Map.new(withdrawal: 101)
    ), false
    assert_equal program.evaluate(
      account: Cel::Map.new(balance: 100, overdraftProtection: true, overdraftLimit: 10),
      transaction: Cel::Map.new(withdrawal: 110)
    ), true
    assert_equal program.evaluate(
      account: Cel::Map.new(balance: 100, overdraftProtection: true, overdraftLimit: 10),
      transaction: Cel::Map.new(withdrawal: 111)
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

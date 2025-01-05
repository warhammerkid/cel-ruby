# frozen_string_literal: true

require_relative "test_helper"

if defined?(Cel::Encoder)
  class CelCompileTest < Minitest::Test
    # Disable all tests temporarily
    def self.runnable_methods
      []
    end

    def test_literal_expression
      # operation
      assert_enc_dec("1 == 2",
                     [
                       "op",
                       "==",
                       ["lit", "int", 1],
                       ["lit", "int", 2],
                     ])

      # complex literals
      assert_enc_dec "[1, 2][0]", [
        "inv",
        [
          "lit",
          "list",
          ["lit", "int", 1],
          ["lit", "int", 2],
        ],
        "[]",
        ["lit", "int", 0],
      ]

      assert_enc_dec "{'a': 1}", [
        "lit",
        "map",
        [%w[lit string a], ["lit", "int", 1]],
      ]
    end

    def test_variable_expression
      assert_enc_dec "a == 2", [
        "op",
        "==",
        %w[id any a],
        ["lit", "int", 2],
      ]

      assert_enc_dec "a == 2", [
        "op",
        "==",
        %w[id int a],
        ["lit", "int", 2],
      ], { a: :int }

      assert_enc_dec "a == 2 ? 1 : 2", [
        "cond",
        [
          "op",
          "==",
          %w[id int a],
          ["lit", "int", 2],
        ],
        ["lit", "int", 1],
        ["lit", "int", 2],
      ], { a: :int }

      assert_enc_dec "(a == 2 || a == 1) && b == 2", [
        "op",
        "&&",
        [
          "group",
          [
            "op", "||",
            ["op", "==", %w[id int a], ["lit", "int", 2]],
            ["op", "==", %w[id int a], ["lit", "int", 1]]
          ],
        ],
        [
          "op", "==", %w[id int b], ["lit", "int", 2]
        ],
      ], { a: :int, b: :int }
    end

    def test_invoke_expressionn
      assert_enc_dec "{'a': 2}.a", [
        "inv",
        [
          "lit",
          "map",
          [%w[lit string a], ["lit", "int", 2]],
        ],
        "a",
      ]

      # functions
      assert_enc_dec "timestamp('2022-12-25T00:00:00Z')", [
        "inv",
        "timestamp",
        ["lit", "string", "2022-12-25T00:00:00Z"],
      ]
      assert_enc_dec "size(\"helloworld\")", [
        "inv",
        "size",
        %w[lit string helloworld],
      ]

      assert_enc_dec "'helloworld'.contains('fuzz')", [
        "inv",
        %w[lit string helloworld],
        "contains",
        %w[lit string fuzz],
      ]
    end

    def test_proto_expression
      # protobuf
      assert_enc_dec "google.protobuf.BoolValue{value: true}", [
        "lit",
        "bool",
        true,
      ]
    end

    def test_macros
      assert_enc_dec "[1, 2, 3].all(e, e > 0)", [
        "inv",
        [
          "lit",
          "list",
          ["lit", "int", 1],
          ["lit", "int", 2],
          ["lit", "int", 3],
        ],
        "all",
        %w[id int e],
        [
          "op",
          ">",
          %w[id int e],
          ["lit", "int", 0],
        ],
      ]
    end

    private

    def assert_enc_dec(expr, enc, bindings = {})
      env = environment(bindings)
      assert_equal enc, env.encode(expr)
      assert_equal env.decode(enc), env.compile(expr)
    end

    def environment(*args)
      Cel::Environment.new(*args)
    end
  end
end

## [Unreleased]

## [0.2.0] - 2023-01-17

### Features

#### Timestamp/Duration types

Implementing `Cel::Timestamp` and `Cel::Duration` CEL types, along with support for functions for those types (such as `getDate`, `getDayOfYear`).

```ruby
Cel::Environment.new.evaluate("timestamp('2022-12-25T00:00:00Z').getDate()") #=> 25
Cel::Environment.new.evaluate("duration('3600s10ms').getHours()") #=> 1
```

#### Protobuf-to-CEL conversion

Support for auto-conversion of certain protobuf messages in the `google.protobf` package to CEL types.

https://github.com/google/cel-spec/blob/master/doc/langdef.md#dynamic-values

```ruby
Cel::Environment.new.evaluate("google.protobuf.BoolValue{value: true}") #=> true
Cel::Environment.new.evaluate("google.protobuf.Value{string_value: 'bla'}") #=> "bla"
```

#### Custom Functions

`cel` supports the definition of custom functions in the environment, to be used in expressions:

```ruby
Cel::Environment.new(foo: Cel::Function(:int, :int, return_type: :int) { |a, b| a + b }).evaluate("foo(2, 2)") #=> 4
```

### Expression encoding/decoding

Expressions can now be encoded and decoded, to improve storage / reparsing to and from JSON, for example.

```ruby
enc = Cel::Environment.new.encode("1 == 2") #=> ["op", ...
store_to_db(JSON.dump(enc))

# then, somewhere else
env = Cel::Environment.new
ast = env.decode(JSON.parse(read_from_db))
env.evaluate(ast) #=> 3
```

**NOTE**: This feature is only available in ruby 3.1 .

### Bugfixes

* fixed parser bug disallowing identifiers composed "true" or "false" (such as "true_name").

## [0.1.2] - 2022-11-10

point release to update links in rubygems.

## [0.1.1] - 2022-08-11

* fixed handling of comparison of primmitive types with Cel types.
* fixed truffleruby compatibility by improving parser number handling.

## [0.1.0] - 2021-11-23

- Initial release

# Cel::Ruby

[![Gem Version](https://badge.fury.io/rb/cel.svg)](http://rubygems.org/gems/cel)
[![pipeline status](https://gitlab.com/os85/cel-ruby/badges/master/pipeline.svg)](https://gitlab.com/os85/cel-ruby/pipelines?page=1&scope=all&ref=master)
[![coverage report](https://gitlab.com/os85/cel-ruby/badges/master/coverage.svg?job=coverage)](https://os85.gitlab.io/cel-ruby/coverage/#_AllFiles)

Pure Ruby implementation of Google Common Expression Language, https://opensource.google/projects/cel.

> The Common Expression Language (CEL) implements common semantics for expression evaluation, enabling different applications to more easily interoperate.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cel'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install cel

## Usage

The usage pattern follows the pattern defined by [cel-go](https://github.com/google/cel-go), i.e. define an environment, which then can be used to parse, compile and evaluate a CEL program.

```ruby
require "cel"

# set the environment
env = Cel::Environment.new(name: :string, group: :string)

# 1.1 parse
ast = env.parse('name.startsWith("/groups/" + group)') #=> Cel::AST::Expr
# 1.2 check
env.check(ast)
# 1.3 evaluate
prg = env.program(ast)
return_value = prg.evaluate(name: Cel::String.new("/groups/acme.co/documents/secret-stuff"),
    group: Cel::String.new("acme.co"))

# 2.1 parse and check
ast = env.compile('name.startsWith("/groups/" + group)')
# 2.2 then evaluate
prg = env.program(ast)
return_value = prg.evaluate(name: Cel::String.new("/groups/acme.co/documents/secret-stuff"),
    group: Cel::String.new("acme.co"))

# 3. or parse, check and evaluate
begin
  return_value = env.evaluate(
    'name.startsWith("/groups/" + group)',
    name: Cel::String.new("/groups/acme.co/documents/secret-stuff"),
    group: Cel::String.new("acme.co")
  )
rescue Cel::Error => e
  STDERR.puts("evaluation error: #{e.message}")
  raise e
end

puts return_value #=> true
```

### types

`cel-ruby` supports declaring the types of variables in the environment, which allows for expression checking:

```ruby
env = Cel::Environment.new(
  first_name: :string, # shortcut for Cel::Types[:string]
  middle_names: Cel::Types[:list, :string], # list of strings
  last_name: :string
)

# you can use Cel::Types to access any type of primitive type, i.e. Cel::Types[:bytes]
```

### protobuf

If `google/protobuf` is available in the environment, `cel-ruby` will also be able to integrate with protobuf declarations in CEL expressions.

```ruby
require "google/protobuf"
require "cel"

env = Cel::Environment.new

env.evaluate("google.protobuf.Duration{seconds: 123}.seconds == 123") #=> true
```

### Custom functions

`cel-ruby` allows you to define custom functions to be used insde CEL expressions. While we **strongly** recommend usage of `Cel::Function` for defining them (due to the ability of them being used for checking), the only requirement is that the function object responds to `.call`:

```ruby
env = environment(foo: Cel::Function(:int, :int, return_type: :int) { |a, b|  a + b})
env.evaluate("foo(2, 2)") #=> 4

# this is also possible, just not as type-safe
env2 = environment(foo: -> (a, b) { a + b})
env2.evaluate("foo(2, 2)") #=> 4
```

## Supported Rubies

All Rubies greater or equal to 2.7, and always latest JRuby and Truffleruby.

## Development

Clone the repo in your local machine, where you have `ruby` installed. Then you can:

```bash
# install dev dependencies
> bundle install
# run tests
> bundle exec rake test
```

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### CEL parser

The parser is based on the grammar defined in [cel-spec](https://github.com/google/cel-spec/blob/master/doc/langdef.md#syntax), and developed using [racc](https://github.com/ruby/racc), a LALR(1) parser generator, which is part of ruby's standard library.

Changes in the parser are therefore accomplished by modifying the `parser.ry` file and running:

```bash
> bundle exec racc -o lib/cel/parser.rb lib/cel/parser.ry
```

## Contributing

Bug reports and pull requests are welcome on Gitlab at https://gitlab.com/os85/cel-ruby.

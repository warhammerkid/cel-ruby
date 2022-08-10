# Cel::Ruby

[![Gem Version](https://badge.fury.io/rb/cel.svg)](http://rubygems.org/gems/cel)
[![pipeline status](https://gitlab.com/honeyryderchuck/cel-ruby/badges/master/pipeline.svg)](https://gitlab.com/honeyryderchuck/cel-ruby/pipelines?page=1&scope=all&ref=master)
[![coverage report](https://gitlab.com/honeyryderchuck/cel-ruby/badges/master/coverage.svg?job=coverage)](https://honeyryderchuck.gitlab.io/cel-ruby/coverage/#_AllFiles)

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
begin
  ast = env.compile('name.startsWith("/groups/" + group)') #=> Cel::Types[:bool], which is == :bool
rescue Cel::Error => e
  STDERR.puts("type-check error: #{e.message}")
  raise e
end
# 1.2 check
prg = env.program(ast)
# 1.3 evaluate
return_value = prg.evaluate(name: Cel::String.new("/groups/acme.co/documents/secret-stuff"),
    group: Cel::String.new("acme.co")))

# 2.1 parse and check
prg = env.program('name.startsWith("/groups/" + group)')
# 2.2 then evaluate
return_value = prg.evaluate(name: Cel::String.new("/groups/acme.co/documents/secret-stuff"),
    group: Cel::String.new("acme.co")))

# 3. or parse, check and evaluate
begin
  return_value = env.evaluate(ast,
    name: Cel::String.new("/groups/acme.co/documents/secret-stuff"),
    group: Cel::String.new("acme.co"))
rescue Cel::Error => e
  STDERR.puts("evaluation error: #{e.message}")
  raise e
end

puts return_value #=> true
```

### protobuf

If `google/protobuf` is available in the environment, `cel-ruby` will also be able to integrate with protobuf declarations in CEL expressions.

```ruby
# gem "google-protobuf" in your Gemfile
require "cel"

env = Cel::Environment.new

env.evaluate("google.protobuf.Duration{seconds: 123}.seconds == 123") #=> true
```


## Supported Rubies

All Rubies greater or equal to 2.5, and always latest JRuby and Truffleruby.

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

Bug reports and pull requests are welcome on Gitlab at https://gitlab.com/honeyryderchuck/cel-ruby.

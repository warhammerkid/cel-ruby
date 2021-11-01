# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in cel-ruby.gemspec
gemspec

gem "rake", "~> 13.0"

gem "pry-byebug", platform: :mri
gem "rubocop"
gem "rubocop-performance"

if RUBY_VERSION < "2.5"
  gem "simplecov", "< 0.21.0"
else
  gem "simplecov"
end

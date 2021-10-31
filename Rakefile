# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new do |t|
  t.libs = %w[lib test]
  t.pattern = "test/**/*_test.rb"
  t.warning = false
end

require "standard/rake"

task default: %i[test]

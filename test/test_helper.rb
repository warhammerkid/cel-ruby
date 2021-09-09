# frozen_string_literal: true

GC.auto_compact = true if GC.respond_to?(:auto_compact=)

require "minitest"
require "minitest/autorun"

if ENV.key?("PARALLEL")
  require "minitest/hell"
  class Minitest::Test
    parallelize_me!
  end
end

require "cel"

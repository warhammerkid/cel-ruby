# frozen_string_literal: true

require "bigdecimal"
require "cel/version"
require "cel/errors"
require "cel/function_bindings"
require "cel/ast/types"
require "cel/ast/elements"
require "cel/parser"
require "cel/container"
require "cel/context"
require "cel/function_registry"
require "cel/standard_functions"
require "cel/program"
require "cel/environment"
require "cel/protobuf"

module Cel
  def self.to_numeric(anything)
    num = BigDecimal(anything.to_s)
    if num.frac.zero?
      num.to_i
    else
      num.to_f
    end
  end
end

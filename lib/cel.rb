# frozen_string_literal: true

require "bigdecimal"
require "cel/version"
require "cel/errors"
require "cel/ast/types"
require "cel/ast/elements"
require "cel/parser"
require "cel/context"
require "cel/program"
require "cel/environment"

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

# frozen_string_literal: true

require "bigdecimal"
require "cel/version"
require "cel/errors"
require "cel/ast/types"
require "cel/parser"
require "cel/macro"
require "cel/context"
require "cel/checker"
require "cel/program"
require "cel/environment"

begin
  require "google/protobuf/well_known_types"
  require "cel/protobuf"
rescue LoadError # rubocop:disable Lint/SuppressedException
end

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

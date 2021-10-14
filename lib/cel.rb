# frozen_string_literal: true

require "cel/version"

require "cel/parser"
require "cel/context"
require "cel/checker"
require "cel/program"
require "cel/environment"

module Cel
  class Error < StandardError; end
end
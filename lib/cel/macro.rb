# frozen_string_literal: true

module Cel
  module Macro
    def self.rewrite_global(function, args)
      case function
      when "has" then rewrite_has(args)
      end
    end

    def self.rewrite_has(args)
      unless args.size == 1 && args[0].is_a?(Cel::AST::Select)
        raise Cel::ParseError, "has() macro expects select argument"
      end

      args[0].tap { |s| s.test_only = true }
    end
  end
end

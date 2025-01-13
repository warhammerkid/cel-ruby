# frozen_string_literal: true

module Cel
  class Program
    class Comprehension < Program
      def initialize(context, container, comprehension)
        super(context, container)
        @comprehension = comprehension
        @accumulator = nil
        @iter_var = nil
      end

      def call
        # Set up evaluation
        @accumulator = evaluate(@comprehension.accu_init)
        iterator_value = evaluate(@comprehension.iter_range)

        # Run comprehension
        iterator_value.to_enum.each do |value|
          @iter_var = value
          @accumulator = evaluate(@comprehension.loop_step)
          break unless evaluate(@comprehension.loop_condition).value
        end

        evaluate(@comprehension.result)
      end

      private

      def evaluate_identifier(ast)
        if ast.name == @comprehension.accu_var
          @accumulator
        elsif ast.name == @comprehension.iter_var
          @iter_var
        else
          super
        end
      end
    end
  end
end

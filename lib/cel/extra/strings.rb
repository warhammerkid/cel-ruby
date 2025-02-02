# frozen_string_literal: true

require "base64"
require "cel/extra/formatting"

module Cel
  module Extra
    module Strings
      class << self
        extend FunctionBindings

        cel_func { receiver_function("charAt", :string, %i[int], :string) }
        def char_at(string, index)
          str = string.value
          i = index.value
          raise EvaluateError, "Index out of bounds: #{i}" if i.negative? || i > str.length

          String.new(i == str.length ? "" : str[i])
        end

        cel_func do
          receiver_function("indexOf", :string, %i[string], :int)
          receiver_function("indexOf", :string, %i[string int], :int)
        end
        def index_of(string, match, start = nil)
          i = start&.value || 0
          raise EvaluateError, "Start out of bounds: #{i}" if i.negative?

          Number.new(:int, string.value.index(match.value, i) || -1)
        end

        cel_func do
          receiver_function("lastIndexOf", :string, %i[string], :int)
          receiver_function("lastIndexOf", :string, %i[string int], :int)
        end
        def last_index_of(string, match, start = nil)
          str = string.value
          i = start&.value || str.length
          raise EvaluateError, "Start out of bounds: #{i}" if i.negative?

          Number.new(:int, str.rindex(match.value, i) || -1)
        end

        cel_func { receiver_function("lowerAscii", :string, [], :string) }
        def lower_ascii(string)
          String.new(string.value.downcase(:ascii))
        end

        cel_func do
          receiver_function("replace", :string, %i[string string], :string)
          receiver_function("replace", :string, %i[string string int], :string)
        end
        def replace(string, match, replace, count = nil)
          count_value = count&.value
          if count_value.nil? || count_value.negative?
            String.new(string.value.gsub(match.value, replace.value))
          elsif count_value.zero?
            string
          else
            replace_value = replace.value
            result = string.value.gsub(match.value) do |m|
              next m if count_value.zero?

              count_value -= 1
              replace_value
            end
            String.new(result)
          end
        end

        cel_func do
          receiver_function("split", :string, %i[string], ListType[:string])
          receiver_function("split", :string, %i[string int], ListType[:string])
        end
        def split(string, match, count = nil)
          count_value = count&.value || -1
          return List.new([]) if count_value.zero?

          items =
            if count_value.negative?
              string.value.split(match.value, -1) # No limit
            else
              string.value.split(match.value, count_value)
            end
          items.map! { |s| String.new(s) }

          List.new(items)
        end

        cel_func do
          receiver_function("substring", :string, %i[int], :string)
          receiver_function("substring", :string, %i[int int], :string)
        end
        def substring(string, start, end_index = nil)
          str = string.value
          i = start.value
          len = str.length
          raise EvaluateError, "Start out of bounds: #{i}" if i.negative? || i > len

          return String.new(str[i..]) if end_index.nil?

          end_value = end_index.value
          raise EvaluateError, "Invalid range: start #{i} end #{end_value}" if i > end_value
          raise EvaluateError, "End out of bounds: #{end_value}" if end_value.negative? || end_value > len

          String.new(str[i...end_value])
        end

        TRIM_REGEXP = /^[[:space:]]*(.*?)[[:space:]]*$/
        cel_func { receiver_function("trim", :string, [], :string) }
        def trim(string)
          output = string.value.sub(TRIM_REGEXP, '\1')
          String.new(output)
        end

        cel_func { receiver_function("upperAscii", :string, [], :string) }
        def upper_ascii(string)
          String.new(string.value.upcase(:ascii))
        end

        #
        # Version 1
        #

        cel_func { receiver_function("format", :string, [ListType[:any]], :string) }
        def format_string(string, args)
          String.new(Formatting.new(string.value).call(args))
        end

        cel_func { global_function("strings.quote", [:string], :string) }
        def quote(string)
          String.new(string.value.inspect)
        end

        #
        # Version 2
        #

        cel_func do
          receiver_function("join", ListType[:string], [], :string)
          receiver_function("join", ListType[:string], [:string], :string)
        end
        def join(list, delimiter = nil)
          delimiter_str = delimiter ? delimiter.value : ""
          list_strs = list.value.map(&:value)
          String.new(list_strs.join(delimiter_str))
        end

        #
        # Version 3
        #

        cel_func { receiver_function("reverse", :string, [], :string) }
        def reverse(string)
          String.new(string.value.reverse)
        end
      end
    end
  end
end

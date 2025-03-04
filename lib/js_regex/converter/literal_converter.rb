require_relative 'base'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class LiteralConverter < JsRegex::Converter::Base
      class << self
        ASTRAL_PLANE_CODEPOINT_PATTERN = /[\u{10000}-\u{10FFFF}]/

        def convert_data(data, context)
          if data =~ ASTRAL_PLANE_CODEPOINT_PATTERN
            if context.enable_u_option
              escape_incompatible_bmp_literals(data)
            else
              convert_astral_data(data)
            end
          else
            escape_incompatible_bmp_literals(data)
          end
        end

        def convert_astral_data(data)
          data.each_char.each_with_object(Node.new) do |char, node|
            if char =~ ASTRAL_PLANE_CODEPOINT_PATTERN
              node << surrogate_substitution_for(char)
            else
              node << escape_incompatible_bmp_literals(char)
            end
          end
        end

        def escape_incompatible_bmp_literals(data)
          data.gsub('/', '\\/').gsub(/[\f\n\r\t]/) { |lit| Regexp.escape(lit) }
        end

        private

        def surrogate_substitution_for(char)
          CharacterSet::Writer.write_surrogate_ranges([], [char.codepoints])
        end
      end

      private

      def convert_data
        result = self.class.convert_data(data, context)
        if context.case_insensitive_root && !expression.case_insensitive?
          warn_of_unsupported_feature('nested case-sensitive literal')
        elsif !context.case_insensitive_root && expression.case_insensitive?
          return handle_locally_case_insensitive_literal(result)
        end
        result
      end

      HAS_CASE_PATTERN = /[\p{lower}\p{upper}]/

      def handle_locally_case_insensitive_literal(literal)
        literal =~ HAS_CASE_PATTERN ? case_insensitivize(literal) : literal
      end

      def case_insensitivize(literal)
        literal.each_char.each_with_object(Node.new) do |chr, node|
          node << (chr =~ HAS_CASE_PATTERN ? "[#{chr}#{chr.swapcase}]" : chr)
        end
      end
    end
  end
end

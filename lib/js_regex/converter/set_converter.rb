require_relative 'base'
require_relative 'escape_converter'
require_relative 'type_converter'
require 'character_set'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    # Unlike other converters, this one does not recurse on subexpressions,
    # since many are unsupported by JavaScript. If it detects incompatible
    # children, it uses the `character_set` gem to establish the codepoints
    # matched by the whole set and build a completely new set string.
    #
    class SetConverter < JsRegex::Converter::Base
      private

      def convert_data
        return pass_through_with_escaping if directly_compatible?

        content = CharacterSet.of_expression(expression)
        if expression.case_insensitive? && !context.case_insensitive_root
          content = content.case_insensitive
        elsif !expression.case_insensitive? && context.case_insensitive_root
          warn_of_unsupported_feature('nested case-sensitive set')
        end

        if context.es_2015_or_higher?
          context.enable_u_option if content.astral_part?
          content.to_s(format: 'es6', in_brackets: true)
        else
          content.to_s_with_surrogate_ranges
        end
      end

      def directly_compatible?
        all_children_directly_compatible? && !casefolding_needed?
      end

      def all_children_directly_compatible?
        # note that #each_expression is recursive
        expression.each_expression.all? { |ch| child_directly_compatible?(ch) }
      end

      def child_directly_compatible?(exp)
        case exp.type
        when :literal
          # surrogate pair substitution needed on ES2009 if astral
          exp.text.ord <= 0xFFFF || context.enable_u_option
        when :set
          # conversion needed for nested sets, intersections
          exp.token.equal?(:range)
        when :type
          TypeConverter.directly_compatible?(exp)
        when :escape
          EscapeConverter::ESCAPES_SHARED_BY_RUBY_AND_JS.include?(exp.token)
        end
      end

      def casefolding_needed?
        expression.case_insensitive? ^ context.case_insensitive_root
      end

      def pass_through_with_escaping
        string = expression.to_s(:base)
        LiteralConverter.escape_incompatible_bmp_literals(string)
      end
    end
  end
end

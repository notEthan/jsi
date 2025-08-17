# frozen_string_literal: true

module JSI
  module Schema
    Cxt = Struct.subclass(*%i(
      schema
      abort
    ))

    # @!attribute schema
    #   The schema invoking an action in this context
    #   @return [JSI::Schema]
    class Cxt
      def subschema(subptr)
        schema.subschema(subptr)
      end

      def schema_content
        schema.jsi_node_content
      end

      def keyword?(keyword)
        schema.keyword?(keyword)
      end

      # @return [Boolean]
      def keyword_value_hash?(keyword)
        keyword?(keyword) && schema_content[keyword].respond_to?(:to_hash)
      end

      # @return [Boolean]
      def keyword_value_ary?(keyword)
        keyword?(keyword) && schema_content[keyword].respond_to?(:to_ary)
      end

      # @return [Boolean]
      def keyword_value_str?(keyword)
        keyword?(keyword) && schema_content[keyword].respond_to?(:to_str)
      end

      # @return [Boolean]
      def keyword_value_bool?(keyword)
        keyword?(keyword) && (schema_content[keyword] == true || schema_content[keyword] == false)
      end

      # @return [Boolean]
      def keyword_value_numeric?(keyword)
        keyword?(keyword) && schema_content[keyword].is_a?(Numeric)
      end

      # is `value` an integer?
      # @return [Boolean]
      def internal_integer?(value)
        if schema.dialect.conf[:integer_disallows_0_fraction]
          value.is_a?(Integer)
        else
          value.is_a?(Integer) || (value.is_a?(Numeric) && value % 1.0 == 0.0)
        end
      end
    end

    class Cxt
      autoload(:InplaceApplication, 'jsi/schema/cxt/inplace_application')
      autoload(:ChildApplication, 'jsi/schema/cxt/child_application')
    end

    Cxt::Block = Cxt.subclass(:block)

    # @!attribute block
    #   @return [#call]
    class Cxt::Block < Cxt
      if Util::LAST_ARGUMENT_AS_KEYWORD_PARAMETERS
        def cxt_yield(*a)
          block.call(*a)
        end
      else
        def cxt_yield(*a, **kw)
          block.call(*a, **kw)
        end
      end
    end
  end
end

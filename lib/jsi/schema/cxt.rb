# frozen_string_literal: true

module JSI
  module Schema
    Cxt = Util::AttrStruct[*%w(
      schema
      abort
    )]

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
      def internal_integer?(value)
        schema.internal_integer?(value)
      end
    end

    class Cxt
      autoload(:InplaceApplication, 'jsi/schema/cxt/inplace_application')
      autoload(:ChildApplication, 'jsi/schema/cxt/child_application')
    end

    Cxt::Block = Cxt.subclass('block')

    # @!attribute block
    #   @return [#call]
    class Cxt::Block
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

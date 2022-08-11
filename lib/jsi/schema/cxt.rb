# frozen_string_literal: true

module JSI
  module Schema
    Cxt = Util::AttrStruct[*%w(
      schema
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
    end

    Cxt::Block = Cxt.subclass('block')

    # @!attribute block
    #   @return [#call]
    class Cxt::Block
    end
  end
end

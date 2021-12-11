# frozen_string_literal: true

module JSI
  module Schema
    Cxt = Util::AttrStruct[*%w(
      schema
    )]

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
  end
end

# frozen_string_literal: true

module JSI
  class Schema::Cxt
    InplaceApplication = Block.subclass(*%w(
      instance
      visited_refs
    ))

    class InplaceApplication
      # @param subschema_ptr [Ptr, #to_ary]
      def inplace_subschema_applicate(subschema_ptr)
        inplace_schema_applicate(schema.subschema(subschema_ptr))
      end

      # @param applicator_schema [Schema]
      def inplace_schema_applicate(applicator_schema)
        applicator_schema.each_inplace_applicator_schema(
          instance,
          visited_refs: visited_refs,
          &block
        )
      end
    end
  end
end

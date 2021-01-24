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
        schema.subschema(subschema_ptr).each_inplace_applicator_schema(
          instance,
          visited_refs: visited_refs,
          &block
        )
      end
    end
  end
end

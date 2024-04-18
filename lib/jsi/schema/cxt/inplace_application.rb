# frozen_string_literal: true

module JSI
  class Schema::Cxt
    InplaceApplication = Block.subclass(*%w(
      instance
      visited_refs
      collect_evaluated
    ))

    # @!attribute collect_evaluated
    #   Does application need to collect successful child evaluation?
    #   @return [Boolean]
    class InplaceApplication
      # @param subschema_ptr [Ptr, #to_ary]
      def inplace_subschema_applicate(subschema_ptr)
        inplace_schema_applicate(schema.subschema(subschema_ptr))
      end

      # @param applicator_schema [Schema]
      # @param ref [Schema::Ref, nil]
      def inplace_schema_applicate(applicator_schema, ref: nil)
        block.call(applicator_schema, ref: ref)
      end
    end
  end
end

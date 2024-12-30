# frozen_string_literal: true

module JSI
  class Schema::Cxt
    InplaceApplication = Block.subclass(*%i(
      instance
      visited_refs
      collect_evaluated
    ))

    # @!attribute collect_evaluated
    #   Does application need to collect successful child evaluation?
    #   @return [Boolean]
    class InplaceApplication
      # @param subschema_ptr [Ptr, #to_ary]
      def inplace_subschema_applicate(subschema_ptr, **kw)
        inplace_schema_applicate(schema.subschema(subschema_ptr), **kw)
      end

      # @param applicator_schema [Schema]
      def inplace_schema_applicate(applicator_schema, **kw)
        block.call(applicator_schema, **kw)
      end
    end
  end
end

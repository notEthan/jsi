# frozen_string_literal: true

module JSI
  class Schema::Cxt
    ChildApplication = Block.subclass(*%w(
      instance
      token
      evaluated
    ))

    # @!attribute evaluated
    #   Was the child successfully evaluated by a child applicator?
    #   @return [Boolean]
    class ChildApplication
      # @param subschema_ptr [Ptr, #to_ary]
      def child_subschema_applicate(subschema_ptr)
        child_schema_applicate(schema.subschema(subschema_ptr))
      end

      # @param child_applicator_schema [Schema]
      def child_schema_applicate(child_applicator_schema)
        cxt_yield(child_applicator_schema)
      end
    end
  end
end

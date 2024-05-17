# frozen_string_literal: true

module JSI
  class Schema::Cxt
    InplaceApplication = Block.subclass(*%i(
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

      def instance
        raise(Bug, "in-place application is being invoked without an instance; the current element needs action :inplace_application_requires_instance")
      end
    end

    InplaceApplication::WithInstance = InplaceApplication.subclass(*%i(
      instance
    ))
  end
end

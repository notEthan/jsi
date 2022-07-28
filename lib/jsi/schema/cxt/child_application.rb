# frozen_string_literal: true

module JSI
  class Schema::Cxt
    ChildApplication = Block.subclass(*%w(
      instance
      token
    ))

    class ChildApplication
      # @param subschema_ptr [Ptr, #to_ary]
      def child_subschema_applicate(subschema_ptr)
        cxt_yield(schema.subschema(subschema_ptr))
      end
    end
  end
end

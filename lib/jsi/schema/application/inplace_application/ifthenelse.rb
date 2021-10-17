# frozen_string_literal: true

module JSI
  module Schema::Application::InplaceApplication::IfThenElse
    # @private
    def internal_applicate_ifthenelse(instance, visited_refs, &block)
      if schema_content.key?('if')
        if subschema(['if']).instance_valid?(instance)
          if schema_content.key?('then')
            subschema(['then']).each_inplace_applicator_schema(instance, visited_refs: visited_refs, &block)
          end
        else
          if schema_content.key?('else')
            subschema(['else']).each_inplace_applicator_schema(instance, visited_refs: visited_refs, &block)
          end
        end
      end
    end
  end
end

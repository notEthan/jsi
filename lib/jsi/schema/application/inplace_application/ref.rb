# frozen_string_literal: true

module JSI
  module Schema::Application::InplaceApplication::Ref
    # @private
    def internal_applicate_ref(instance, visited_refs, throw_done: false, &block)
      if keyword?('$ref') && schema_content['$ref'].respond_to?(:to_str)
        ref = schema_ref
        unless visited_refs.include?(ref)
          ref.deref_schema.each_inplace_applicator_schema(instance, visited_refs: visited_refs + [ref], &block)
          if throw_done
            throw(:jsi_application_done)
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module JSI
  module Schema::Elements
    REF = element_map do
      throw_done = true
      Schema::Element.new do |element|
        element.add_action(:inplace_applicate) do
      if keyword?('$ref') && schema_content['$ref'].respond_to?(:to_str)
        ref = schema.schema_ref('$ref')
        unless visited_refs.include?(ref)
          ref.deref_schema.each_inplace_applicator_schema(instance, visited_refs: visited_refs + [ref], &block)
          if throw_done
            throw(:jsi_application_done)
          end
        end
      end
        end # element.add_action(:inplace_applicate)
      end # Schema::Element.new
    end # REF = element_map
  end # module Schema::Elements
end

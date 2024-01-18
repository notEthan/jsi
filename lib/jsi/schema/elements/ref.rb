# frozen_string_literal: true

module JSI
  module Schema::Elements
    REF = element_map do
      exclusive = true
      Schema::Element.new do |element|
        element.add_action(:inplace_applicate) do
      if keyword?('$ref') && schema_content['$ref'].respond_to?(:to_str)
        ref = schema.schema_ref('$ref')
        unless visited_refs.include?(ref)
          ref.deref_schema.each_inplace_applicator_schema(instance, visited_refs: visited_refs + [ref], &block)
          if exclusive
            throw(:jsi_application_done)
          end
        end
      end
        end # element.add_action(:inplace_applicate)

        element.add_action(:validate) do
          if keyword?('$ref')
            value = schema_content['$ref']

            if value.respond_to?(:to_str)
              schema_ref = schema.schema_ref('$ref')

              if visited_refs.include?(schema_ref)
                schema_error('self-referential schema structure', '$ref')
              else
                ref_result = schema_ref.deref_schema.internal_validate_instance(
                  instance_ptr,
                  instance_document,
                  validate_only: validate_only,
                  visited_refs: visited_refs + [schema_ref],
                )
                validate(
                  ref_result.valid?,
                  "instance is not valid against the schema referenced by `$ref`",
                  keyword: '$ref',
                  results: [ref_result],
                )
                if exclusive
                  throw(:jsi_validation_result, result)
                end
              end
            else
              schema_error("`$ref` is not a string", '$ref')
            end
          end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # REF = element_map
  end # module Schema::Elements
end

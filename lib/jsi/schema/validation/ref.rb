# frozen_string_literal: true

module JSI
  module Schema::Validation::Ref
    # @private
    # @param throw_result [Boolean] if a $ref is present, whether to throw the result being built after
    #   validating the $ref, bypassing subsequent keyword validation
    def internal_validate_ref(result_builder, throw_result: false)
      if schema_content.key?('$ref')
        value = schema_content['$ref']

        if value.respond_to?(:to_str)
          schema_ref = jsi_memoize(:ref) { Schema::Ref.new(value, self) }

          if result_builder.visited_refs.include?(schema_ref)
            result_builder.schema_error('self-referential schema structure', '$ref')
          else
            ref_result = schema_ref.deref_schema.internal_validate_instance(
              result_builder.instance_ptr,
              result_builder.instance_document,
              validate_only: result_builder.validate_only,
              visited_refs: result_builder.visited_refs + [schema_ref],
            )
            result_builder.validate(
              ref_result.valid?,
              'instance is not valid against the schema referenced by `$ref` value',
              keyword: '$ref',
              results: [ref_result],
            )
            if throw_result
              throw(:jsi_validation_result, result_builder.result)
            end
          end
        else
          result_builder.schema_error("`$ref` is not a string", '$ref')
        end
      end
    end
  end
end

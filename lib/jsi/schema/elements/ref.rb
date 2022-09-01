# frozen_string_literal: true

module JSI
  module Schema::Elements
    # exclusive [Boolean]: whether to abort invocation of subsequent actions when a $ref is evaluated
    REF = element_map do |exclusive: |
      Schema::Element.new do |element|
        if exclusive
          # $ref must come before all other elements to abort evaluation
          element.required_before_elements { |_| true }

          actions_to_abort = [
            :id,
            :id_without_fragment,
            :anchor,
          ]
          actions_to_abort.each do |action|
            element.add_action(action) { self.abort = true if keyword?('$ref') }
          end
        end

        element.add_action(:inplace_applicate) do
      if keyword?('$ref') && schema_content['$ref'].respond_to?(:to_str)
        ref = schema.schema_ref('$ref')
        unless visited_refs.include?(ref)
          inplace_schema_applicate(ref.deref_schema, ref: ref)

          if exclusive
            self.abort = true
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
                next
              end

                ref_result = schema_ref.deref_schema.internal_validate_instance(
                  instance_ptr,
                  instance_document,
                  validate_only: validate_only,
                  visited_refs: visited_refs + [schema_ref],
                )
                validate(
                  ref_result.valid?,
                  'validation.keyword.$ref.invalid',
                  "instance is not valid against the schema referenced by `$ref`",
                  keyword: '$ref',
                  results: [ref_result],
                )
                if exclusive
                  self.abort = true
                end
            end
          end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # REF = element_map
  end # module Schema::Elements
end

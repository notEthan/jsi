# frozen_string_literal: true

module JSI
  module Schema::Elements
    # exclusive [Boolean]: whether to abort invocation of subsequent actions when a $ref is evaluated
    REF = element_map do |exclusive: |
      Schema::Element.new(keyword: '$ref') do |element|
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

        resolve_ref = proc do
          next if !keyword_value_str?('$ref')
          ref = schema.schema_ref('$ref')
          resolved_schema = ref.deref_schema.jsi_with_schema_dynamic_anchor_map(schema.jsi_next_schema_dynamic_anchor_map)
          [resolved_schema, ref]
        end

        element.add_action(:inplace_applicate) do
          resolved_schema, ref = *instance_exec(&resolve_ref) || next

          inplace_schema_applicate(resolved_schema, ref: ref)

          if exclusive
            self.abort = true
          end
        end # element.add_action(:inplace_applicate)

        element.add_action(:validate) do
                resolved_schema, schema_ref = *instance_exec(&resolve_ref) || next

                ref_result = resolved_schema.internal_validate_instance(
                  instance_ptr,
                  instance_document,
                  validate_only: validate_only,
                  visited_refs: Util.add_visited_ref(visited_refs, schema_ref),
                )
                inplace_results_validate(
                  ref_result.valid?,
                  'validation.keyword.$ref.invalid',
                  "instance is not valid against the schema referenced by `$ref`",
                  keyword: '$ref',
                  results: [ref_result],
                )
                if exclusive
                  self.abort = true
                end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # REF = element_map
  end # module Schema::Elements
end

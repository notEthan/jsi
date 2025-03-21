# frozen_string_literal: true

module JSI
  module Schema::Elements
    DYNAMIC_REF = element_map do
      Schema::Element.new(keyword: '$dynamicRef') do |element|
        resolve_dynamicRef = proc do
          next unless keyword_value_str?('$dynamicRef')

          dynamic_anchor_map = schema.jsi_next_schema_dynamic_anchor_map

          #> Resolved against the current URI base, it produces the URI used as the starting point for runtime resolution.
          #> This initial resolution is safe to perform on schema load.
          ref = schema.schema_ref('$dynamicRef')

          initial_resolution = ref.resolve

          #> If the initially resolved starting point URI includes a
          #> fragment that was created by the "$dynamicAnchor" keyword,
          resolve_dynamically = \
            # did resolution resolve a fragment?
            ref.ref_uri.fragment &&
            # does the fragment correspond to a dynamicAnchor? (not a regular anchor, not a pointer)
            initial_resolution.dialect_invoke_each(:dynamicAnchor).include?(ref.ref_uri.fragment) &&
            # is the anchor in our dynamic_anchor_map?
            dynamic_anchor_map.key?(ref.ref_uri.fragment)
          if resolve_dynamically
            #> the initial URI MUST be replaced by the URI (including the fragment)
            #> for the outermost schema resource in the dynamic scope (Section 7.1)
            #> that defines an identically named fragment with "$dynamicAnchor".

            # our dynamic resolution doesn't use a stack of dynamic scope URIs.
            # we replace the initially resolved resource with the resource from dynamic_anchor_map.

            scope_schema, subptrs = dynamic_anchor_map[ref.ref_uri.fragment]
            resolved_schema = subptrs.inject(scope_schema, &:subschema)
          else
            #> Otherwise, its behavior is identical to "$ref", and no runtime resolution is needed.
            resolved_schema = initial_resolution
          end

          [resolved_schema.with_dynamic_scope_from(schema), ref]
        end

        element.add_action(:inplace_applicate) do
          resolved_schema, ref = *instance_exec(&resolve_dynamicRef) || next
          inplace_schema_applicate(resolved_schema, ref: ref)
        end

        element.add_action(:validate) do
          resolved_schema, ref = *instance_exec(&resolve_dynamicRef) || next
          ref_result = resolved_schema.internal_validate_instance(
            instance_ptr,
            instance_document,
            validate_only: validate_only,
            visited_refs: Util.add_visited_ref(visited_refs, ref),
          )
          inplace_results_validate(
            ref_result.valid?,
            'validation.keyword.$dynamicRef.invalid',
            "instance is not valid against the schema referenced by `$dynamicRef`",
            keyword: '$dynamicRef',
            results: [ref_result],
          )
        end
      end
    end
  end
end

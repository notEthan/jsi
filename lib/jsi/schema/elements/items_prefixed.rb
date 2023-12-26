# frozen_string_literal: true

module JSI
  module Schema::Elements
    ITEMS_PREFIXED = element_map do
      Schema::Element.new(keywords: %w(items prefixItems)) do |element|
        element.add_action(:subschema) do
          # https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-01#name-prefixitems
          #> The value of "prefixItems" MUST be a non-empty array of valid JSON Schemas.
          if keyword_value_ary?('prefixItems')
            schema_content['prefixItems'].each_index do |i|
              cxt_yield(['prefixItems', i])
            end
          end

          # https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-01#name-items
          #> The value of "items" MUST be a valid JSON Schema.
          if keyword?('items')
            cxt_yield(['items'])
          end
        end

        element.add_action(:child_applicate) do
          next if !instance.respond_to?(:to_ary)
          if keyword_value_ary?('prefixItems') && schema_content['prefixItems'].size > token
            child_subschema_applicate(['prefixItems', token])
          elsif keyword?('items')
            child_subschema_applicate(['items'])
          end
        end

        element.add_action(:validate) do
          next if !instance.respond_to?(:to_ary)
          i = 0
          if keyword_value_ary?('prefixItems')
            prefixItems_results = {}

            while i < schema_content['prefixItems'].size && i < instance.size
              prefixItems_results[i] = child_subschema_validate(i, ['prefixItems', i])

              i += 1
            end

            #> Validation succeeds if each element of the instance validates
            #> against the schema at the same position, if any.
            #> This keyword does not constrain the length of the array.
            #> If the array is longer than this keyword's value, this keyword
            #> validates only the prefix of matching length.
            child_results_validate(
              prefixItems_results.each_value.all?(&:valid?),
              'validation.keyword.prefixItems.invalid',
              "instance array items are not all valid against corresponding `prefixItems` schemas",
              keyword: 'prefixItems',
              child_results: prefixItems_results,
              instance_indexes_valid: prefixItems_results.inject({}) { |h, (ri, r)| h.update({ri => r.valid?}) }.freeze,
            )
          end

          if keyword?('items')
            items_results = {}

            while i < instance.size
              #> This keyword applies its subschema to all instance elements at indexes
              #> greater than the length of the "prefixItems" array in the same schema
              #> object, as reported by the annotation result of that "prefixItems" keyword.
              #> If no such annotation result exists, "items" applies its subschema to all instance array elements.
              #> Note that the behavior of "items" without "prefixItems" is identical
              #> to that of the schema form of "items" in prior drafts.
              #> When "prefixItems" is present, the behavior of "items" is identical
              #> to the former "additionalItems" keyword.
              items_results[i] = child_subschema_validate(i, ['items'])

              i += 1
            end

            if keyword_value_ary?('prefixItems')
              error_key = 'validation.keyword.items.after_prefixItems.invalid'
              error_msg = "instance array items after `prefixItems` are not all valid against `items` schema"
            else
              error_key = 'validation.keyword.items.invalid'
              error_msg = "instance array items are not all valid against `items` schema"
            end
            child_results_validate(
              items_results.each_value.all?(&:valid?),
              error_key,
              error_msg,
              keyword: 'items',
              child_results: items_results,
              instance_indexes_valid: items_results.inject({}) { |h, (ri, r)| h.update({ri => r.valid?}) }.freeze,
            )
          end
        end
      end
    end
  end
end

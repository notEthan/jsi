# frozen_string_literal: true

module JSI
  module Schema::Elements
    ITEMS = element_map do
      Schema::Element.new(keywords: %w(items additionalItems)) do |element|
        element.add_action(:subschema) do
          if keyword?('items')
            #> The value of "items" MUST be either a valid JSON Schema or an array of valid JSON Schemas.
            if keyword_value_ary?('items')
              schema_content['items'].each_index do |i|
                cxt_yield(['items', i])
              end
            else
              cxt_yield(['items'])
            end
          end

          if keyword?('additionalItems')
            #> The value of "additionalItems" MUST be a valid JSON Schema.
            cxt_yield(['additionalItems'])
          end
        end # element.add_action(:subschema)

        element.add_action(:child_applicate) do
    if instance.respond_to?(:to_ary)
      if keyword?('items') && schema_content['items'].respond_to?(:to_ary)
        if schema_content['items'].size > token
          child_subschema_applicate(['items', token])
        elsif keyword?('additionalItems')
          child_subschema_applicate(['additionalItems'])
        end
      elsif keyword?('items')
        child_subschema_applicate(['items'])
      end
    end # if instance.respond_to?(:to_ary)
        end # element.add_action(:child_applicate)

        element.add_action(:validate) do
          if instance.respond_to?(:to_ary)
            if keyword?('items')
              #> The value of "items" MUST be either a valid JSON Schema or an array of valid JSON Schemas.
              if schema_content['items'].respond_to?(:to_ary)
                #> If "items" is an array of schemas, validation succeeds if each element of the instance
                #> validates against the schema at the same position, if any.
                items_results = {}
                additionalItems_results = {}
                instance.each_index do |i|
                  if i < schema_content['items'].size
                    items_results[i] = child_subschema_validate(i, ['items', i])
                  elsif keyword?('additionalItems')
                    additionalItems_results[i] = child_subschema_validate(i, ['additionalItems'])
                  end
                end
                child_results_validate(
                  items_results.each_value.all?(&:valid?),
                  'validation.keyword.items.array.invalid',
                  "instance array items are not all valid against corresponding `items` schemas",
                  keyword: 'items',
                  child_results: items_results,
                  instance_indexes_valid: items_results.inject({}) { |h, (i, r)| h.update({i => r.valid?}) }.freeze,
                )
                child_results_validate(
                  additionalItems_results.each_value.all?(&:valid?),
                  'validation.keyword.additionalItems.invalid',
                  "instance array items after `items` schemas are not all valid against `additionalItems` schema",
                  keyword: 'additionalItems',
                  child_results: additionalItems_results,
                  instance_indexes_valid: additionalItems_results.inject({}) { |h, (i, r)| h.update({i => r.valid?}) }.freeze,
                )
              else
                #> If "items" is a schema, validation succeeds if all elements in the array successfully
                #> validate against that schema.
                items_results = {}
                instance.each_index do |i|
                  items_results[i] = child_subschema_validate(i, ['items'])
                end
                child_results_validate(
                  items_results.each_value.all?(&:valid?),
                  'validation.keyword.items.schema.invalid',
                  "instance array items are not all valid against `items` schema",
                  keyword: 'items',
                  child_results: items_results,
                  instance_indexes_valid: items_results.inject({}) { |h, (i, r)| h.update({i => r.valid?}) }.freeze,
                )
              end
            end
          end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # ITEMS = element_map
  end # module Schema::Elements
end

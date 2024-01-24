# frozen_string_literal: true

module JSI
  module Schema::Elements
    ITEMS = element_map do
      Schema::Element.new do |element|
        element.add_action(:child_applicate) do
    if instance.respond_to?(:to_ary)
      if keyword?('items') && schema_content['items'].respond_to?(:to_ary)
        if schema_content['items'].each_index.to_a.include?(token)
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
                validate(
                  items_results.each_value.all?(&:valid?),
                  "instance array items are not all valid against corresponding `items` schemas",
                  keyword: 'items',
                  results: items_results.each_value,
                )
                validate(
                  additionalItems_results.each_value.all?(&:valid?),
                  "instance array items after `items` schemas are not all valid against `additionalItems` schema",
                  keyword: 'additionalItems',
                  results: additionalItems_results.each_value,
                )
              else
                #> If "items" is a schema, validation succeeds if all elements in the array successfully
                #> validate against that schema.
                items_results = {}
                instance.each_index do |i|
                  items_results[i] = child_subschema_validate(i, ['items'])
                end
                validate(
                  items_results.each_value.all?(&:valid?),
                  "instance array items are not all valid against `items` schema",
                  keyword: 'items',
                  results: items_results.each_value,
                )
              end
              if keyword?('additionalItems')
                schema_warning('`additionalItems` has no effect when adjacent `items` keyword is not an array', 'items')
              end
            end
          else
            if keyword?('additionalItems')
              schema_warning('`additionalItems` has no effect without adjacent `items` keyword', 'items')
            end
          end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # ITEMS = element_map
  end # module Schema::Elements
end

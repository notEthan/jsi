# frozen_string_literal: true

module JSI
  module Schema::Elements
    ITEMS = element_map do
      Schema::Element.new do |element|
        element.add_action(:child_applicate) do
    if instance.respond_to?(:to_ary)
      if keyword?('items') && schema_content['items'].respond_to?(:to_ary)
        if schema_content['items'].each_index.to_a.include?(token)
          cxt_yield(subschema(['items', token]))
        elsif keyword?('additionalItems')
          cxt_yield(subschema(['additionalItems']))
        end
      elsif keyword?('items')
        cxt_yield(subschema(['items']))
      end
    end # if instance.respond_to?(:to_ary)
        end # element.add_action(:child_applicate)

        element.add_action(:validate) do
          if keyword?('items')
            value = schema_content['items']
            # The value of "items" MUST be either a valid JSON Schema or an array of valid JSON Schemas.
            if value.respond_to?(:to_ary)
              # If "items" is an array of schemas, validation succeeds if each element of the instance validates
              # against the schema at the same position, if any.
              if instance.respond_to?(:to_ary)
                results = {}
                instance.each_index do |i|
                  if i < value.size
                    results[i] = child_subschema_validate(i, ['items', i])
                  elsif keyword?('additionalItems')
                    results[i] = child_subschema_validate(i, ['additionalItems'])
                  end
                end
                validate(
                  results.each_value.all?(&:valid?),
                  'instance array items are not all valid against corresponding `items` or `additionalItems` schema values',
                  keyword: 'items',
                  results: results.each_value,
                )
              end
            else
              # If "items" is a schema, validation succeeds if all elements in the array successfully validate
              # against that schema.
              if instance.respond_to?(:to_ary)
                results = instance.each_index.map do |i|
                  child_subschema_validate(i, ['items'])
                end
                validate(
                  results.all?(&:valid?),
                  'instance array items are not all valid against `items` schema value',
                  keyword: 'items',
                  results: results,
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

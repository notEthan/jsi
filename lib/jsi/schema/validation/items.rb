# frozen_string_literal: true

module JSI
  module Schema::Validation::Items
    # @private
    def internal_validate_items(result_builder)
      if schema_content.key?('items')
        value = schema_content['items']
        # The value of "items" MUST be either a valid JSON Schema or an array of valid JSON Schemas.
        if value.respond_to?(:to_ary)
          # If "items" is an array of schemas, validation succeeds if each element of the instance validates
          # against the schema at the same position, if any.
          if result_builder.instance.respond_to?(:to_ary)
            results = {}
            result_builder.instance.each_index do |i|
              if i < value.size
                results[i] = result_builder.child_subschema_validate(['items', i], [i])
              elsif schema_content.key?('additionalItems')
                results[i] = result_builder.child_subschema_validate(['additionalItems'], [i])
              end
            end
            result_builder.validate(
              results.values.all?(&:valid?),
              'instance array items are not all valid against corresponding `items` or `additionalItems` schema values',
              keyword: 'items',
              results: results.values,
            )
          end
        else
          # If "items" is a schema, validation succeeds if all elements in the array successfully validate
          # against that schema.
          if result_builder.instance.respond_to?(:to_ary)
            results = result_builder.instance.each_index.map do |i|
              result_builder.child_subschema_validate(['items'], [i])
            end
            result_builder.validate(
              results.all?(&:valid?),
              'instance array items are not all valid against `items` schema value',
              keyword: 'items',
              results: results,
            )
          end
          if schema_content.key?('additionalItems')
            result_builder.schema_warning('`additionalItems` has no effect when adjacent `items` keyword is not an array', 'items')
          end
        end
      else
        if schema_content.key?('additionalItems')
          result_builder.schema_warning('`additionalItems` has no effect without adjacent `items` keyword', 'items')
        end
      end
    end
  end
end

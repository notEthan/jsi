# frozen_string_literal: true

module JSI
  module Schema::Validation::PropertyNames
    # @private
    def internal_validate_propertyNames(result_builder)
      if schema_content.key?('propertyNames')
        # The value of "propertyNames" MUST be a valid JSON Schema.
        #
        # If the instance is an object, this keyword validates if every property name in the instance
        # validates against the provided schema. Note the property name that the schema is testing will
        # always be a string.
        if result_builder.instance.respond_to?(:to_hash)
          results = result_builder.instance.keys.map do |property_name|
            subschema(['propertyNames']).internal_validate_instance(
              Ptr[],
              property_name,
              validate_only: result_builder.validate_only,
            )
          end
          result_builder.validate(
            results.all?(&:valid?),
            'instance object property names are not all valid against `propertyNames` schema value',
            keyword: 'propertyNames',
            results: results,
          )
        end
      end
    end
  end
end

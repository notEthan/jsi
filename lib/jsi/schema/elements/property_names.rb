# frozen_string_literal: true

module JSI
  module Schema::Elements
    PROPERTY_NAMES = element_map do
      Schema::Element.new(keyword: 'propertyNames') do |element|
        element.add_action(:subschema) do
          if keyword?('propertyNames')
            #> The value of "propertyNames" MUST be a valid JSON Schema.
            cxt_yield(['propertyNames'])
          end
        end # element.add_action(:subschema)

        element.add_action(:propertyNames) do
          cxt_yield(subschema(['propertyNames'])) if keyword?('propertyNames')
        end

        element.add_action(:validate) do
      if keyword?('propertyNames')
        # The value of "propertyNames" MUST be a valid JSON Schema.
        #
        # If the instance is an object, this keyword validates if every property name in the instance
        # validates against the provided schema. Note the property name that the schema is testing will
        # always be a string.
        if instance.respond_to?(:to_hash)
          results = {}
          instance.each_key do |property_name|
            results[property_name] = subschema(['propertyNames']).internal_validate_instance(
              Ptr[],
              property_name,
              validate_only: validate_only,
            )
          end
          validate(
            results.each_value.all?(&:valid?),
            'validation.keyword.propertyNames.invalid',
            "instance object property names are not all valid against `propertyNames` schema",
            keyword: 'propertyNames',
            results: results.each_value,
            instance_property_names_valid: results.inject({}) { |h, (k, r)| h.update({k => r.valid?}) }.freeze,
          )
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # PROPERTY_NAMES = element_map
  end # module Schema::Elements
end

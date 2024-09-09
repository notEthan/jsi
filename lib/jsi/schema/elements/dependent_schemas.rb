# frozen_string_literal: true

module JSI
  module Schema::Elements
    DEPENDENT_SCHEMAS = element_map do
      Schema::Element.new(keyword: 'dependentSchemas') do |element|
        element.add_action(:validate) do
          #> This keyword's value MUST be an object.
          next if !keyword_value_hash?('dependentSchemas')
          next if !instance.respond_to?(:to_hash)

          #> This keyword specifies subschemas that are evaluated if the
          #> instance is an object and contains a certain property.
          #
          #> If the object key is a property in the instance, the entire instance must validate
          #> against the subschema. Its use is dependent on the presence of the property.
          results = {}
          schema_content['dependentSchemas'].each_key do |property_name|
            if instance.key?(property_name)
              results[property_name] = inplace_subschema_validate(['dependentSchemas', property_name])
            end
          end
          inplace_results_validate(
            results.each_value.all?(&:valid?),
            'validation.keyword.dependentSchemas.invalid',
            "instance object is not valid against all schemas corresponding to matched property names specified by `dependentSchemas`",
            keyword: 'dependentSchemas',
            results: results.each_value,
            dependentSchemas_properties_valid: results.inject({}) { |h, (k, r)| h.update({k => r.valid?}) }.freeze,
          )
        end
      end
    end
  end
end

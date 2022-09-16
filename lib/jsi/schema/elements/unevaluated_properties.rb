# frozen_string_literal: true

module JSI
  module Schema::Elements
    # https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-01#name-unevaluatedproperties
    UNEVALUATED_PROPERTIES = element_map do
      Schema::Element.new(keyword: 'unevaluatedProperties') do |element|
        element.add_action(:subschema) do
          #> The value of "unevaluatedProperties" MUST be a valid JSON Schema.
          if keyword?('unevaluatedProperties')
            cxt_yield(['unevaluatedProperties'])
          end
        end

        element.add_action(:validate) do
          next if !keyword?('unevaluatedProperties')
          next if !instance.respond_to?(:to_hash)
          results = {}
          instance.each_key do |property_name|
            if !result.evaluated_tokens.include?(property_name)
              results[property_name] = child_subschema_validate(property_name, ['unevaluatedProperties'])
            end
          end

          child_results_validate(
            results.each_value.all?(&:valid?),
            'validation.keyword.unevaluatedProperties.invalid',
            "instance object unevaluated properties are not all valid against `unevaluatedProperties` schema",
            keyword: 'unevaluatedProperties',
            child_results: results,
            instance_properties_valid: results.inject({}) { |h, (k, r)| h.update({k => r.valid?}) }.freeze,
          )
        end
      end
    end
  end
end

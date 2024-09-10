# frozen_string_literal: true

module JSI
  module Schema::Elements
    PROPERTIES = element_map do
      Schema::Element.new(keywords: %w(properties patternProperties additionalProperties)) do |element|
        element.add_action(:subschema) do
          #> The value of "properties" MUST be an object.
          if keyword_value_hash?('properties')
            schema_content['properties'].each_key do |property_name|
              #> Each value of this object MUST be a valid JSON Schema.
              cxt_yield(['properties', property_name])
            end
          end

          #> The value of "patternProperties" MUST be an object.
          if keyword_value_hash?('patternProperties')
            schema_content['patternProperties'].each_key do |pattern|
              #> Each property value of this object MUST be a valid JSON Schema.
              cxt_yield(['patternProperties', pattern])
            end
          end

          if keyword?('additionalProperties')
            #> The value of "additionalProperties" MUST be a valid JSON Schema.
            cxt_yield(['additionalProperties'])
          end
        end # element.add_action(:subschema)

        element.add_action(:described_object_property_names) do
          next if !keyword_value_hash?('properties')
          schema_content['properties'].each_key(&block)
        end

        element.add_action(:child_applicate) do
    if instance.respond_to?(:to_hash)
      apply_additional = true
      if keyword?('properties') && schema_content['properties'].respond_to?(:to_hash) && schema_content['properties'].key?(token)
        apply_additional = false
        child_subschema_applicate(['properties', token])
      end
      if keyword?('patternProperties') && schema_content['patternProperties'].respond_to?(:to_hash)
        schema_content['patternProperties'].each_key do |pattern|
          if pattern.respond_to?(:to_str) && token.to_s =~ Regexp.new(pattern) # TODO map pattern to ruby syntax
            apply_additional = false
            child_subschema_applicate(['patternProperties', pattern])
          end
        end
      end
      if apply_additional && keyword?('additionalProperties')
        child_subschema_applicate(['additionalProperties'])
      end
    end # if instance.respond_to?(:to_hash)
        end # element.add_action(:child_applicate)

        element.add_action(:validate) do
          evaluated_property_names = Set[]

          if keyword?('properties')
            value = schema_content['properties']
            # The value of "properties" MUST be an object. Each value of this object MUST be a valid JSON Schema.
            if value.respond_to?(:to_hash)
              # Validation succeeds if, for each name that appears in both the instance and as a name within this
              # keyword's value, the child instance for that name successfully validates against the corresponding
              # schema.
              if instance.respond_to?(:to_hash)
                results = {}
                instance.each_key do |property_name|
                  if value.key?(property_name)
                    evaluated_property_names << property_name
                    results[property_name] = child_subschema_validate(property_name, ['properties', property_name])
                  end
                end
                child_results_validate(
                  results.each_value.all?(&:valid?),
                  'validation.keyword.properties.invalid',
                  "instance object properties are not all valid against corresponding `properties` schemas",
                  keyword: 'properties',
                  child_results: results,
                  instance_properties_valid: results.inject({}) { |h, (k, r)| h.update({k => r.valid?}) }.freeze,
                )
              end
            end
          end

          if keyword?('patternProperties')
            value = schema_content['patternProperties']
            # The value of "patternProperties" MUST be an object. Each property name of this object SHOULD be a
            # valid regular expression, according to the ECMA 262 regular expression dialect. Each property value
            # of this object MUST be a valid JSON Schema.
            if value.respond_to?(:to_hash)
              # Validation succeeds if, for each instance name that matches any regular expressions that appear as
              # a property name in this keyword's value, the child instance for that name successfully validates
              # against each schema that corresponds to a matching regular expression.
              if instance.respond_to?(:to_hash)
                results = {}
                instance.each_key do |property_name|
                  value.each_key do |value_property_pattern|
                    begin
                      # TODO ECMA 262
                      if value_property_pattern.respond_to?(:to_str) && Regexp.new(value_property_pattern).match(property_name.to_s)
                        evaluated_property_names << property_name
                        results[property_name] = child_subschema_validate(property_name, ['patternProperties', value_property_pattern])
                      end
                    rescue ::RegexpError
                      # cannot validate
                    end
                  end
                end
                child_results_validate(
                  results.each_value.all?(&:valid?),
                  'validation.keyword.patternProperties.invalid',
                  "instance object properties are not all valid against matching `patternProperties` schemas",
                  keyword: 'patternProperties',
                  child_results: results,
                  instance_properties_valid: results.inject({}) { |h, (k, r)| h.update({k => r.valid?}) }.freeze,
                )
              end
            end
          end

          if keyword?('additionalProperties')
            # The value of "additionalProperties" MUST be a valid JSON Schema.
            if instance.respond_to?(:to_hash)
              results = {}
              instance.each_key do |property_name|
                if !evaluated_property_names.include?(property_name)
                  results[property_name] = child_subschema_validate(property_name, ['additionalProperties'])
                end
              end
              child_results_validate(
                results.each_value.all?(&:valid?),
                'validation.keyword.additionalProperties.invalid',
                "instance object additional properties are not all valid against `additionalProperties` schema",
                keyword: 'additionalProperties',
                child_results: results,
                instance_properties_valid: results.inject({}) { |h, (k, r)| h.update({k => r.valid?}) }.freeze,
              )
            end
          end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # PROPERTIES = element_map
  end # module Schema::Elements
end

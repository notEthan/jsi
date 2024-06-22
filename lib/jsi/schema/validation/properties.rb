# frozen_string_literal: true

module JSI
  module Schema::Validation::Properties
    # @private
    def internal_validate_properties(result_builder)
      evaluated_property_names = Set[]

      if keyword?('properties')
        value = schema_content['properties']
        # The value of "properties" MUST be an object. Each value of this object MUST be a valid JSON Schema.
        if value.respond_to?(:to_hash)
          # Validation succeeds if, for each name that appears in both the instance and as a name within this
          # keyword's value, the child instance for that name successfully validates against the corresponding
          # schema.
          if result_builder.instance.respond_to?(:to_hash)
            results = {}
            result_builder.instance.keys.each do |property_name|
              if value.key?(property_name)
                evaluated_property_names << property_name
                results[property_name] = result_builder.child_subschema_validate(
                  property_name,
                  ['properties', property_name],
                )
              end
            end
            result_builder.validate(
              results.values.all?(&:valid?),
              'instance object properties are not all valid against corresponding `properties` schema values',
              keyword: 'properties',
              results: results.values,
            )
          end
        else
          result_builder.schema_error('`properties` is not an object', 'properties')
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
          if result_builder.instance.respond_to?(:to_hash)
            results = {}
            result_builder.instance.keys.each do |property_name|
              value.keys.each do |value_property_pattern|
                begin
                  # TODO ECMA 262
                  if value_property_pattern.respond_to?(:to_str) && Regexp.new(value_property_pattern).match(property_name.to_s)
                    evaluated_property_names << property_name
                    results[property_name] = result_builder.child_subschema_validate(
                      property_name,
                      ['patternProperties', value_property_pattern],
                    )
                  end
                rescue ::RegexpError
                  result_builder.schema_error("`patternProperties` key #{property_name.inspect} is not a valid regular expression: #{e.message}", 'patternProperties')
                end
              end
            end
            result_builder.validate(
              results.values.all?(&:valid?),
              'instance object properties are not all valid against corresponding `patternProperties` schema values',
              keyword: 'patternProperties',
              results: results.values,
            )
          end
        else
          result_builder.schema_error('`patternProperties` is not an object', 'patternProperties')
        end
      end

      if keyword?('additionalProperties')
        value = schema_content['additionalProperties']
        # The value of "additionalProperties" MUST be a valid JSON Schema.
        if result_builder.instance.respond_to?(:to_hash)
          results = {}
          result_builder.instance.keys.each do |property_name|
            if !evaluated_property_names.include?(property_name)
              results[property_name] = result_builder.child_subschema_validate(
                property_name,
                ['additionalProperties'],
              )
            end
          end
          result_builder.validate(
            results.values.all?(&:valid?),
            'instance object additional properties are not all valid against `additionalProperties` schema value',
            keyword: 'additionalProperties',
            results: results.values,
          )
        end
      end
    end
  end
end

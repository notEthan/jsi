# frozen_string_literal: true

module JSI
  module Schema::Elements
    MAXIMUM_BOOLEAN_EXCLUSIVE = element_map do
      Schema::Element.new do |element|
        element.add_action(:validate) do
      if keyword?('exclusiveMaximum')
        value = schema_content['exclusiveMaximum']
        # The value of "exclusiveMaximum" MUST be a boolean.
        unless [true, false].include?(value)
          schema_error('`exclusiveMaximum` is not true or false', 'exclusiveMaximum')
        end
        #> If "exclusiveMaximum" is present, "maximum" MUST also be present.
        if !keyword?('maximum')
          schema_error('`exclusiveMaximum` has no effect without adjacent `maximum` keyword', 'exclusiveMaximum')
        end
      end

      if keyword?('maximum')
        value = schema_content['maximum']
        # The value of "maximum" MUST be a JSON number.
        if value.is_a?(Numeric)
          if instance.is_a?(Numeric)
            # Successful validation depends on the presence and value of "exclusiveMaximum":
            if schema_content['exclusiveMaximum'] == true
              # if "exclusiveMaximum" has boolean value true, the instance is valid if it is strictly lower
              # than the value of "maximum".
              validate(
                instance < value,
                'instance is not less than `maximum` value with `exclusiveMaximum` = true',
                keyword: 'maximum',
              )
            else
              # if "exclusiveMaximum" is not present, or has boolean value false, then the instance is
              # valid if it is lower than, or equal to, the value of "maximum"
              validate(
                instance <= value,
                'instance is not less than or equal to `maximum` value',
                keyword: 'maximum',
              )
            end
          end
        else
          schema_error('`maximum` is not a number', 'maximum')
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # MAXIMUM_BOOLEAN_EXCLUSIVE = element_map
  end # module Schema::Elements

  module Schema::Elements
    MINIMUM_BOOLEAN_EXCLUSIVE = element_map do
      Schema::Element.new do |element|
        element.add_action(:validate) do
      if keyword?('exclusiveMinimum')
        value = schema_content['exclusiveMinimum']
        # The value of "exclusiveMinimum" MUST be a boolean.
        unless [true, false].include?(value)
          schema_error('`exclusiveMinimum` is not true or false', 'exclusiveMinimum')
        end
        #> If "exclusiveMinimum" is present, "minimum" MUST also be present.
        if !keyword?('minimum')
          schema_error('`exclusiveMinimum` has no effect without adjacent `minimum` keyword', 'exclusiveMinimum')
        end
      end

      if keyword?('minimum')
        value = schema_content['minimum']
        # The value of "minimum" MUST be a JSON number.
        if value.is_a?(Numeric)
          if instance.is_a?(Numeric)
            # Successful validation depends on the presence and value of "exclusiveMinimum":
            if schema_content['exclusiveMinimum'] == true
              # if "exclusiveMinimum" is present and has boolean value true, the instance is valid if it is
              # strictly greater than the value of "minimum".
              validate(
                instance > value,
                'instance is not greater than `minimum` value with `exclusiveMinimum` = true',
                keyword: 'minimum',
              )
            else
              # if "exclusiveMinimum" is not present, or has boolean value false, then the instance is
              # valid if it is greater than, or equal to, the value of "minimum"
              validate(
                instance >= value,
                'instance is not greater than or equal to `minimum` value',
                keyword: 'minimum',
              )
            end
          end
        else
          schema_error('`minimum` is not a number', 'minimum')
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # MINIMUM_BOOLEAN_EXCLUSIVE = element_map
  end # module Schema::Elements
end

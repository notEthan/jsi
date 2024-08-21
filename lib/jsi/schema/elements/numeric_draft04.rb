# frozen_string_literal: true

module JSI
  module Schema::Elements
    MAXIMUM_BOOLEAN_EXCLUSIVE = element_map do
      Schema::Element.new do |element|
        element.add_action(:validate) do
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
                'validation.keyword.maximum.with_exclusiveMaximum.greater_or_equal',
                "instance is greater than or equal to `maximum` value with `exclusiveMaximum` = true",
                keyword: 'maximum',
              )
            else
              # if "exclusiveMaximum" is not present, or has boolean value false, then the instance is
              # valid if it is lower than, or equal to, the value of "maximum"
              validate(
                instance <= value,
                'validation.keyword.maximum.greater',
                "instance is greater than `maximum` value",
                keyword: 'maximum',
              )
            end
          end
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
                'validation.keyword.minimum.with_exclusiveMinimum.less_or_equal',
                "instance is less than or equal to `minimum` value with `exclusiveMinimum` = true",
                keyword: 'minimum',
              )
            else
              # if "exclusiveMinimum" is not present, or has boolean value false, then the instance is
              # valid if it is greater than, or equal to, the value of "minimum"
              validate(
                instance >= value,
                'validation.keyword.minimum.less',
                "instance is less than `minimum` value",
                keyword: 'minimum',
              )
            end
          end
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # MINIMUM_BOOLEAN_EXCLUSIVE = element_map
  end # module Schema::Elements
end

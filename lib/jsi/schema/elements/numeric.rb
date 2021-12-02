# frozen_string_literal: true

module JSI
  module Schema::Elements
    MULTIPLE_OF = element_map do
      Schema::Element.new do |element|
        element.add_action(:validate) do
      if keyword?('multipleOf')
        value = schema_content['multipleOf']
        # The value of "multipleOf" MUST be a number, strictly greater than 0.
        if value.is_a?(Numeric) && value > 0
          # A numeric instance is valid only if division by this keyword's value results in an integer.
          if instance.is_a?(Numeric)
            if instance.is_a?(Integer) && value.is_a?(Integer)
              valid = instance % value == 0
            else
              quotient = instance / value
              if quotient.finite?
                valid = quotient % 1.0 == 0.0
              else
                valid = BigDecimal(instance, Float::DIG) % BigDecimal(value, Float::DIG) == 0
              end
            end
            validate(
              valid,
              'instance is not a multiple of `multipleOf` value',
              keyword: 'multipleOf',
            )
          end
        else
          schema_error('`multipleOf` is not a number greater than 0', 'multipleOf')
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # MULTIPLE_OF = element_map
  end # module Schema::Elements

  module Schema::Elements
    MAXIMUM = element_map do
      Schema::Element.new do |element|
        element.add_action(:validate) do
      if keyword?('maximum')
        value = schema_content['maximum']
        # The value of "maximum" MUST be a number, representing an inclusive upper limit for a numeric instance.
        if value.is_a?(Numeric)
          # If the instance is a number, then this keyword validates only if the instance is less than or
          # exactly equal to "maximum".
          if instance.is_a?(Numeric)
            validate(
              instance <= value,
              'instance is not less than or equal to `maximum` value',
              keyword: 'maximum',
            )
          end
        else
          schema_error('`maximum` is not a number', 'maximum')
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # MAXIMUM = element_map
  end # module Schema::Elements

  module Schema::Elements
    EXCLUSIVE_MAXIMUM = element_map do
      Schema::Element.new do |element|
        element.add_action(:validate) do
      if keyword?('exclusiveMaximum')
        value = schema_content['exclusiveMaximum']
        # The value of "exclusiveMaximum" MUST be number, representing an exclusive upper limit for a numeric instance.
        if value.is_a?(Numeric)
          # If the instance is a number, then the instance is valid only if it has a value strictly less than
          # (not equal to) "exclusiveMaximum".
          if instance.is_a?(Numeric)
            validate(
              instance < value,
              'instance is not less than `exclusiveMaximum` value',
              keyword: 'exclusiveMaximum',
            )
          end
        else
          schema_error('`exclusiveMaximum` is not a number', 'exclusiveMaximum')
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # EXCLUSIVE_MAXIMUM = element_map
  end # module Schema::Elements

  module Schema::Elements
    MINIMUM = element_map do
      Schema::Element.new do |element|
        element.add_action(:validate) do
      if keyword?('minimum')
        value = schema_content['minimum']
        # The value of "minimum" MUST be a number, representing an inclusive lower limit for a numeric instance.
        if value.is_a?(Numeric)
          # If the instance is a number, then this keyword validates only if the instance is greater than or
          # exactly equal to "minimum".
          if instance.is_a?(Numeric)
            validate(
              instance >= value,
              'instance is not greater than or equal to `minimum` value',
              keyword: 'minimum',
            )
          end
        else
          schema_error('`minimum` is not a number', 'minimum')
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # MINIMUM = element_map
  end # module Schema::Elements

  module Schema::Elements
    EXCLUSIVE_MINIMUM = element_map do
      Schema::Element.new do |element|
        element.add_action(:validate) do
      if keyword?('exclusiveMinimum')
        value = schema_content['exclusiveMinimum']
        # The value of "exclusiveMinimum" MUST be number, representing an exclusive lower limit for a numeric instance.
        if value.is_a?(Numeric)
          # If the instance is a number, then the instance is valid only if it has a value strictly greater
          # than (not equal to) "exclusiveMinimum".
          if instance.is_a?(Numeric)
            validate(
              instance > value,
              'instance is not greater than `exclusiveMinimum` value',
              keyword: 'exclusiveMinimum',
            )
          end
        else
          schema_error('`exclusiveMinimum` is not a number', 'exclusiveMinimum')
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # EXCLUSIVE_MINIMUM = element_map
  end # module Schema::Elements
end

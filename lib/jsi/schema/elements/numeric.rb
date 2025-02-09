# frozen_string_literal: true

module JSI
  module Schema::Elements
    MULTIPLE_OF = element_map do
      Schema::Element.new(keyword: 'multipleOf') do |element|
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
              'validation.keyword.multipleOf.not_multiple',
              'instance is not a multiple of `multipleOf` value',
              keyword: 'multipleOf',
            )
          end
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # MULTIPLE_OF = element_map
  end # module Schema::Elements

  module Schema::Elements
    MAXIMUM = element_map do
      Schema::Element.new(keyword: 'maximum') do |element|
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
              'validation.keyword.maximum.greater',
              "instance is greater than `maximum` value",
              keyword: 'maximum',
            )
          end
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # MAXIMUM = element_map
  end # module Schema::Elements

  module Schema::Elements
    EXCLUSIVE_MAXIMUM = element_map do
      Schema::Element.new(keyword: 'exclusiveMaximum') do |element|
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
              'validation.keyword.exclusiveMaximum.greater_or_equal',
              "instance is greater than or equal to `exclusiveMaximum` value",
              keyword: 'exclusiveMaximum',
            )
          end
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # EXCLUSIVE_MAXIMUM = element_map
  end # module Schema::Elements

  module Schema::Elements
    MINIMUM = element_map do
      Schema::Element.new(keyword: 'minimum') do |element|
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
              'validation.keyword.minimum.less',
              "instance is less than `minimum` value",
              keyword: 'minimum',
            )
          end
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # MINIMUM = element_map
  end # module Schema::Elements

  module Schema::Elements
    EXCLUSIVE_MINIMUM = element_map do
      Schema::Element.new(keyword: 'exclusiveMinimum') do |element|
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
              'validation.keyword.exclusiveMaximum.less_or_equal',
              "instance is less than or equal to `exclusiveMinimum` value",
              keyword: 'exclusiveMinimum',
            )
          end
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # EXCLUSIVE_MINIMUM = element_map
  end # module Schema::Elements
end

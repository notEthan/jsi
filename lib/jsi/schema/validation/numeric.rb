# frozen_string_literal: true

module JSI
  module Schema::Validation::MultipleOf
    # @private
    def internal_validate_multipleOf(result_builder)
      if schema_content.key?('multipleOf')
        value = schema_content['multipleOf']
        # The value of "multipleOf" MUST be a number, strictly greater than 0.
        if value.is_a?(Numeric) && value > 0
          # A numeric instance is valid only if division by this keyword's value results in an integer.
          if result_builder.instance.is_a?(Numeric)
            if result_builder.instance.is_a?(Integer) && value.is_a?(Integer)
              valid = result_builder.instance % value == 0
            else
              quotient = result_builder.instance / value
              if quotient.finite?
                valid = quotient % 1.0 == 0.0
              else
                valid = BigDecimal(result_builder.instance, Float::DIG) % BigDecimal(value, Float::DIG) == 0
              end
            end
            result_builder.validate(
              valid,
              'instance is not a multiple of `multipleOf` value',
              keyword: 'multipleOf',
            )
          end
        else
          result_builder.schema_error('`multipleOf` is not a number greater than 0', 'multipleOf')
        end
      end
    end
  end

  module Schema::Validation::MinMax
    # @private
    def internal_validate_maximum(result_builder)
      if schema_content.key?('maximum')
        value = schema_content['maximum']
        # The value of "maximum" MUST be a number, representing an inclusive upper limit for a numeric instance.
        if value.is_a?(Numeric)
          # If the instance is a number, then this keyword validates only if the instance is less than or
          # exactly equal to "maximum".
          if result_builder.instance.is_a?(Numeric)
            result_builder.validate(
              result_builder.instance <= value,
              'instance is not less than or equal to `maximum` value',
              keyword: 'maximum',
            )
          end
        else
          result_builder.schema_error('`maximum` is not a number', 'maximum')
        end
      end
    end

    # @private
    def internal_validate_exclusiveMaximum(result_builder)
      if schema_content.key?('exclusiveMaximum')
        value = schema_content['exclusiveMaximum']
        # The value of "exclusiveMaximum" MUST be number, representing an exclusive upper limit for a numeric instance.
        if value.is_a?(Numeric)
          # If the instance is a number, then the instance is valid only if it has a value strictly less than
          # (not equal to) "exclusiveMaximum".
          if result_builder.instance.is_a?(Numeric)
            result_builder.validate(
              result_builder.instance < value,
              'instance is not less than `exclusiveMaximum` value',
              keyword: 'exclusiveMaximum',
            )
          end
        else
          result_builder.schema_error('`exclusiveMaximum` is not a number', 'exclusiveMaximum')
        end
      end
    end

    # @private
    def internal_validate_minimum(result_builder)
      if schema_content.key?('minimum')
        value = schema_content['minimum']
        # The value of "minimum" MUST be a number, representing an inclusive lower limit for a numeric instance.
        if value.is_a?(Numeric)
          # If the instance is a number, then this keyword validates only if the instance is greater than or
          # exactly equal to "minimum".
          if result_builder.instance.is_a?(Numeric)
            result_builder.validate(
              result_builder.instance >= value,
              'instance is not greater than or equal to `minimum` value',
              keyword: 'minimum',
            )
          end
        else
          result_builder.schema_error('`minimum` is not a number', 'minimum')
        end
      end
    end

    # @private
    def internal_validate_exclusiveMinimum(result_builder)
      if schema_content.key?('exclusiveMinimum')
        value = schema_content['exclusiveMinimum']
        # The value of "exclusiveMinimum" MUST be number, representing an exclusive lower limit for a numeric instance.
        if value.is_a?(Numeric)
          # If the instance is a number, then the instance is valid only if it has a value strictly greater
          # than (not equal to) "exclusiveMinimum".
          if result_builder.instance.is_a?(Numeric)
            result_builder.validate(
              result_builder.instance > value,
              'instance is not greater than `exclusiveMinimum` value',
              keyword: 'exclusiveMinimum',
            )
          end
        else
          result_builder.schema_error('`exclusiveMinimum` is not a number', 'exclusiveMinimum')
        end
      end
    end
  end
end

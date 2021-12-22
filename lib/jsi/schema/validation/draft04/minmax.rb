# frozen_string_literal: true

module JSI
  module Schema::Validation::Draft04::MinMax
    # @private
    def internal_validate_maximum(result_builder)
      if keyword?('exclusiveMaximum')
        value = schema_content['exclusiveMaximum']
        # The value of "exclusiveMaximum" MUST be a boolean.
        unless [true, false].include?(value)
          result_builder.schema_error('`exclusiveMaximum` is not true or false', 'exclusiveMaximum')
        end
        if !keyword?('maximum')
          result_builder.schema_error('`exclusiveMaximum` has no effect without adjacent `maximum` keyword', 'exclusiveMaximum')
        end
      end

      if keyword?('maximum')
        value = schema_content['maximum']
        # The value of "maximum" MUST be a JSON number.
        if value.is_a?(Numeric)
          if result_builder.instance.is_a?(Numeric)
            # Successful validation depends on the presence and value of "exclusiveMaximum":
            if schema_content['exclusiveMaximum'] == true
              # if "exclusiveMaximum" has boolean value true, the instance is valid if it is strictly lower
              # than the value of "maximum".
              result_builder.validate(
                result_builder.instance < value,
                'instance is not less than `maximum` value with `exclusiveMaximum` = true',
                keyword: 'maximum',
              )
            else
              # if "exclusiveMaximum" is not present, or has boolean value false, then the instance is
              # valid if it is lower than, or equal to, the value of "maximum"
              result_builder.validate(
                result_builder.instance <= value,
                'instance is not less than or equal to `maximum` value',
                keyword: 'maximum',
              )
            end
          end
        else
          result_builder.schema_error('`maximum` is not a number', 'maximum')
        end
      end
    end

    # @private
    def internal_validate_minimum(result_builder)
      if keyword?('exclusiveMinimum')
        value = schema_content['exclusiveMinimum']
        # The value of "exclusiveMinimum" MUST be a boolean.
        unless [true, false].include?(value)
          result_builder.schema_error('`exclusiveMinimum` is not true or false', 'exclusiveMinimum')
        end
        if !keyword?('minimum')
          result_builder.schema_error('`exclusiveMinimum` has no effect without adjacent `minimum` keyword', 'exclusiveMinimum')
        end
      end

      if keyword?('minimum')
        value = schema_content['minimum']
        # The value of "minimum" MUST be a JSON number.
        if value.is_a?(Numeric)
          if result_builder.instance.is_a?(Numeric)
            # Successful validation depends on the presence and value of "exclusiveMinimum":
            if schema_content['exclusiveMinimum'] == true
              # if "exclusiveMinimum" is present and has boolean value true, the instance is valid if it is
              # strictly greater than the value of "minimum".
              result_builder.validate(
                result_builder.instance > value,
                'instance is not greater than `minimum` value with `exclusiveMinimum` = true',
                keyword: 'minimum',
              )
            else
              # if "exclusiveMinimum" is not present, or has boolean value false, then the instance is
              # valid if it is greater than, or equal to, the value of "minimum"
              result_builder.validate(
                result_builder.instance >= value,
                'instance is not greater than or equal to `minimum` value',
                keyword: 'minimum',
              )
            end
          end
        else
          result_builder.schema_error('`minimum` is not a number', 'minimum')
        end
      end
    end
  end
end

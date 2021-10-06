# frozen_string_literal: true

module JSI
  module Schema::Validation::MinMaxProperties
    # @private
    def internal_validate_maxProperties(result_builder)
      if schema_content.key?('maxProperties')
        value = schema_content['maxProperties']
        # The value of this keyword MUST be a non-negative integer.
        if internal_integer?(value) && value >= 0
          if result_builder.instance.respond_to?(:to_hash)
            # An object instance is valid against "maxProperties" if its number of properties is less than, or equal to, the value of this keyword.
            result_builder.validate(
              result_builder.instance.size <= value,
              'instance object contains more properties than `maxProperties` value',
              keyword: 'maxProperties',
            )
          end
        else
          result_builder.schema_error('`maxProperties` is not a non-negative integer', 'maxProperties')
        end
      end
    end

    # @private
    def internal_validate_minProperties(result_builder)
      if schema_content.key?('minProperties')
        value = schema_content['minProperties']
        # The value of this keyword MUST be a non-negative integer.
        if internal_integer?(value) && value >= 0
          if result_builder.instance.respond_to?(:to_hash)
            # An object instance is valid against "minProperties" if its number of properties is greater than, or equal to, the value of this keyword.
            result_builder.validate(
              result_builder.instance.size >= value,
              'instance object contains fewer properties than `minProperties` value',
              keyword: 'minProperties',
            )
          end
        else
          result_builder.schema_error('`minProperties` is not a non-negative integer', 'minProperties')
        end
      end
    end
  end
end

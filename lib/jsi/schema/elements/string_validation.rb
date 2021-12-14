# frozen_string_literal: true

module JSI
  module Schema::Validation::StringLength
    # @private
    def internal_validate_maxLength(result_builder)
      if keyword?('maxLength')
        value = schema_content['maxLength']
        # The value of this keyword MUST be a non-negative integer.
        if internal_integer?(value) && value >= 0
          if result_builder.instance.respond_to?(:to_str)
            # A string instance is valid against this keyword if its length is less than, or equal to, the
            # value of this keyword.
            result_builder.validate(
              result_builder.instance.to_str.length <= value,
              'instance string length is not less than or equal to `maxLength` value',
              keyword: 'maxLength',
            )
          end
        else
          result_builder.schema_error('`maxLength` is not a non-negative integer', 'maxLength')
        end
      end
    end

    # @private
    def internal_validate_minLength(result_builder)
      if keyword?('minLength')
        value = schema_content['minLength']
        # The value of this keyword MUST be a non-negative integer.
        if internal_integer?(value) && value >= 0
          if result_builder.instance.respond_to?(:to_str)
            # A string instance is valid against this keyword if its length is greater than, or equal to, the
            # value of this keyword.
            result_builder.validate(
              result_builder.instance.to_str.length >= value,
              'instance string length is not greater than or equal to `minLength` value',
              keyword: 'minLength',
            )
          end
        else
          result_builder.schema_error('`minLength` is not a non-negative integer', 'minLength')
        end
      end
    end
  end
end

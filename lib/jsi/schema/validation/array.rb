# frozen_string_literal: true

module JSI
  module Schema::Validation::ArrayLength
    # @private
    def internal_validate_maxItems(result_builder)
      if schema_content.key?('maxItems')
        value = schema_content['maxItems']
        # The value of this keyword MUST be a non-negative integer.
        if internal_integer?(value) && value >= 0
          if result_builder.instance.respond_to?(:to_ary)
            # An array instance is valid against "maxItems" if its size is less than, or equal to, the value of this keyword.
            result_builder.validate(
              result_builder.instance.to_ary.size <= value,
              'instance array size is greater than `maxItems` value',
              keyword: 'maxItems',
            )
          end
        else
          result_builder.schema_error('`maxItems` is not a non-negative integer', 'maxItems')
        end
      end
    end

    # @private
    def internal_validate_minItems(result_builder)
      if schema_content.key?('minItems')
        value = schema_content['minItems']
        # The value of this keyword MUST be a non-negative integer.
        if internal_integer?(value) && value >= 0
          if result_builder.instance.respond_to?(:to_ary)
            # An array instance is valid against "minItems" if its size is greater than, or equal to, the value of this keyword.
            result_builder.validate(
              result_builder.instance.to_ary.size >= value,
              'instance array size is less than `minItems` value',
              keyword: 'minItems',
            )
          end
        else
          result_builder.schema_error('`minItems` is not a non-negative integer', 'minItems')
        end
      end
    end
  end
end

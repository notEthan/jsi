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
  module Schema::Validation::UniqueItems
    # @private
    def internal_validate_uniqueItems(result_builder)
      if schema_content.key?('uniqueItems')
        value = schema_content['uniqueItems']
        # The value of this keyword MUST be a boolean.
        if value == false
          # If this keyword has boolean value false, the instance validates successfully.
          # (noop)
        elsif value == true
          if result_builder.instance.respond_to?(:to_ary)
            # If it has boolean value true, the instance validates successfully if all of its elements are unique.
            result_builder.validate(
              result_builder.instance.uniq.size == result_builder.instance.size,
              "instance array items' uniqueness does not match `uniqueItems` value",
              keyword: 'uniqueItems',
            )
          end
        else
          result_builder.schema_error('`uniqueItems` is not a boolean', 'uniqueItems')
        end
      end
    end
  end
end

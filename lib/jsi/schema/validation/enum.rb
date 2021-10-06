# frozen_string_literal: true

module JSI
  module Schema::Validation::Enum
    # @private
    def internal_validate_enum(result_builder)
      if schema_content.key?('enum')
        value = schema_content['enum']
        # The value of this keyword MUST be an array. This array SHOULD have at least one element.
        # Elements in the array SHOULD be unique.
        if value.respond_to?(:to_ary)
          # An instance validates successfully against this keyword if its value is equal to one of the
          # elements in this keyword's array value.
          result_builder.validate(
            value.include?(result_builder.instance),
            'instance is not equal to any `enum` value',
            keyword: 'enum',
          )
        else
          result_builder.schema_error('`enum` is not an array', 'enum')
        end
      end
    end
  end
end

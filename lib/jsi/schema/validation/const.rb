# frozen_string_literal: true

module JSI
  module Schema::Validation::Const
    # @private
    def internal_validate_const(result_builder)
      if keyword?('const')
        value = schema_content['const']
        # The value of this keyword MAY be of any type, including null.
        # An instance validates successfully against this keyword if its value is equal to the value of
        # the keyword.
        result_builder.validate(
          result_builder.instance == value,
          'instance is not equal to `const` value',
          keyword: 'const',
        )
      end
    end
  end
end

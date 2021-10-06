# frozen_string_literal: true

module JSI
  module Schema::Validation::Not
    # @private
    def internal_validate_not(result_builder)
      if schema_content.key?('not')
        # This keyword's value MUST be a valid JSON Schema.
        # An instance is valid against this keyword if it fails to validate successfully against the schema
        # defined by this keyword.
        not_valid = result_builder.inplace_subschema_validate(['not']).valid?
        result_builder.validate(
          !not_valid,
          'instance is valid against the schema specified as `not` value',
          keyword: 'not',
        )
      end
    end
  end
end

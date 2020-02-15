# frozen_string_literal: true

module JSI
  module Schema::Validation::IfThenElse
    # @private
    def internal_validate_ifthenelse(result_builder)
      if schema_content.key?('if')
        # This keyword's value MUST be a valid JSON Schema.
        # This validation outcome of this keyword's subschema has no direct effect on the overall validation
        # result. Rather, it controls which of the "then" or "else" keywords are evaluated.
        if_result = result_builder.inplace_subschema_validate(['if'])

        result_builder.merge_schema_issues(if_result)

        if if_result.valid?
          if schema_content.key?('then')
            then_result = result_builder.inplace_subschema_validate(['then'])
            result_builder.validate(
              then_result.valid?,
              'instance did not validate against the schema defined by `then` value after validating against the schema defined by the `if` value',
              keyword: 'if',
              results: [then_result],
            )
          end
        else
          if schema_content.key?('else')
            else_result = result_builder.inplace_subschema_validate(['else'])
            result_builder.validate(
              else_result.valid?,
              'instance did not validate against the schema defined by `else` value after not validating against the schema defined by the `if` value',
              keyword: 'if',
              results: [else_result],
            )
          end
        end
      end
    end
  end
end

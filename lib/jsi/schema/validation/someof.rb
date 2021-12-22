# frozen_string_literal: true

module JSI
  module Schema::Validation::AllOf
    # @private
    def internal_validate_allOf(result_builder)
      if keyword?('allOf')
        value = schema_content['allOf']
        # This keyword's value MUST be a non-empty array. Each item of the array MUST be a valid JSON Schema.
        if value.respond_to?(:to_ary)
          # An instance validates successfully against this keyword if it validates successfully against all
          # schemas defined by this keyword's value.
          allOf_results = value.each_index.map do |i|
            result_builder.inplace_subschema_validate(['allOf', i])
          end
          result_builder.validate(
            allOf_results.all?(&:valid?),
            'instance is not valid against all schemas specified by `allOf` value',
            keyword: 'allOf',
            results: allOf_results,
          )
        else
          result_builder.schema_error('`allOf` is not an array', 'allOf')
        end
      end
    end
  end

  module Schema::Validation::AnyOf
    # @private
    def internal_validate_anyOf(result_builder)
      if keyword?('anyOf')
        value = schema_content['anyOf']
        # This keyword's value MUST be a non-empty array. Each item of the array MUST be a valid JSON Schema.
        if value.respond_to?(:to_ary)
          # An instance validates successfully against this keyword if it validates successfully against at
          # least one schema defined by this keyword's value.
          # Note that when annotations are being collected, all subschemas MUST be examined so that
          # annotations are collected from each subschema that validates successfully.
          anyOf_results = value.each_index.map do |i|
            result_builder.inplace_subschema_validate(['anyOf', i])
          end
          result_builder.validate(
            anyOf_results.any?(&:valid?),
            'instance is not valid against any schemas specified by `anyOf` value',
            keyword: 'anyOf',
            results: anyOf_results,
          )
        else
          result_builder.schema_error('`anyOf` is not an array', 'anyOf')
        end
      end
    end
  end

  module Schema::Validation::OneOf
    # @private
    def internal_validate_oneOf(result_builder)
      if keyword?('oneOf')
        value = schema_content['oneOf']
        # This keyword's value MUST be a non-empty array. Each item of the array MUST be a valid JSON Schema.
        if value.respond_to?(:to_ary)
          # An instance validates successfully against this keyword if it validates successfully against
          # exactly one schema defined by this keyword's value.
          oneOf_results = value.each_index.map do |i|
            result_builder.inplace_subschema_validate(['oneOf', i])
          end
          if oneOf_results.none?(&:valid?)
            result_builder.validate(
              false,
              'instance is not valid against any schemas specified by `oneOf` value',
              keyword: 'oneOf',
              results: oneOf_results,
            )
          else
            # TODO better info on what schemas passed/failed validation
            result_builder.validate(
              oneOf_results.select(&:valid?).size == 1,
              'instance is valid against more than one schema specified by `oneOf` value',
              keyword: 'oneOf',
              results: oneOf_results,
            )
          end
        else
          result_builder.schema_error('`oneOf` is not an array', 'oneOf')
        end
      end
    end
  end
end

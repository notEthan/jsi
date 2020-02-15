# frozen_string_literal: true

module JSI
  module Schema::Validation::Required
    # @private
    def internal_validate_required(result_builder)
      if schema_content.key?('required')
        value = schema_content['required']
        # The value of this keyword MUST be an array. Elements of this array, if any, MUST be strings, and MUST be unique.
        if value.respond_to?(:to_ary)
          if result_builder.instance.respond_to?(:to_hash)
            # An object instance is valid against this keyword if every item in the array is the name of a property in the instance.
            missing_required = value.reject { |property_name| result_builder.instance.key?(property_name) }
            # TODO include missing required property names in the validation error
            result_builder.validate(
              missing_required.empty?,
              'instance object does not contain all property names specified by `required` value',
              keyword: 'required',
            )
          end
        else
          result_builder.schema_error('`required` is not an array', 'required')
        end
      end
    end
  end
end

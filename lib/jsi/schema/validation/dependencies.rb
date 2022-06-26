# frozen_string_literal: true

module JSI
  module Schema::Validation::Dependencies
    # @private
    def internal_validate_dependencies(result_builder)
      if keyword?('dependencies')
        value = schema_content['dependencies']
        # This keyword's value MUST be an object. Each property specifies a dependency.  Each dependency
        # value MUST be an array or a valid JSON Schema.
        if value.respond_to?(:to_hash)
          value.each_pair do |property_name, dependency|
            if dependency.respond_to?(:to_ary)
              # If the dependency value is an array, each element in the array, if
              # any, MUST be a string, and MUST be unique.  If the dependency key is
              # a property in the instance, each of the items in the dependency value
              # must be a property that exists in the instance.
              if result_builder.instance.respond_to?(:to_hash) && result_builder.instance.key?(property_name)
                missing_required = dependency.reject { |name| result_builder.instance.key?(name) }
                # TODO include property_name / missing dependent required property names in the validation error
                result_builder.validate(
                  missing_required.empty?,
                  'instance object does not contain all dependent required property names specified by `dependencies` value',
                  keyword: 'dependencies',
                )
              end
            else
              # If the dependency value is a subschema, and the dependency key is a
              # property in the instance, the entire instance must validate against
              # the dependency value.
              if result_builder.instance.respond_to?(:to_hash) && result_builder.instance.key?(property_name)
                dependency_result = result_builder.inplace_subschema_validate(['dependencies', property_name])
                # TODO include property_name in the validation error
                result_builder.validate(
                  dependency_result.valid?,
                  'instance object is not valid against the schema corresponding to a matched property name specified by `dependencies` value',
                  keyword: 'dependencies',
                  results: [dependency_result],
                )
              end
            end
          end
        else
          result_builder.schema_error('`dependencies` is not an object', 'dependencies')
        end
      end
    end
  end
end

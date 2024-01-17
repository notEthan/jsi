# frozen_string_literal: true

module JSI
  module Schema::Elements
    DEPENDENCIES = element_map do
      Schema::Element.new do |element|
        element.add_action(:inplace_applicate) do
      if keyword?('dependencies')
        value = schema_content['dependencies']
        # This keyword's value MUST be an object. Each property specifies a dependency.  Each dependency
        # value MUST be an array or a valid JSON Schema.
        if value.respond_to?(:to_hash)
          value.each_pair do |property_name, dependency|
            if dependency.respond_to?(:to_ary)
              # noop: array-form dependencies has no inplace applicator schema
            else
              # If the dependency value is a subschema, and the dependency key is a
              # property in the instance, the entire instance must validate against
              # the dependency value.
              if instance.respond_to?(:to_hash) && instance.key?(property_name)
                subschema(['dependencies', property_name]).each_inplace_applicator_schema(instance, visited_refs: visited_refs, &block)
              end
            end
          end
        end
      end
        end # element.add_action(:inplace_applicate)

        element.add_action(:validate) do
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
                  if instance.respond_to?(:to_hash) && instance.key?(property_name)
                    missing_required = dependency.reject { |name| instance.key?(name) }.freeze
                    validate(
                      missing_required.empty?,
                      'instance object does not contain all dependent required property names specified by `dependencies` value',
                      keyword: 'dependencies',
                      property_name: property_name,
                      missing_dependent_required_property_names: missing_required,
                    )
                  end
                else
                  # If the dependency value is a subschema, and the dependency key is a
                  # property in the instance, the entire instance must validate against
                  # the dependency value.
                  if instance.respond_to?(:to_hash) && instance.key?(property_name)
                    dependency_result = inplace_subschema_validate(['dependencies', property_name])
                    validate(
                      dependency_result.valid?,
                      'instance object is not valid against the schema corresponding to a matched property name specified by `dependencies` value',
                      keyword: 'dependencies',
                      results: [dependency_result],
                      property_name: property_name,
                    )
                  end
                end
              end
            else
              schema_error('`dependencies` is not an object', 'dependencies')
            end
          end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # DEPENDENCIES = element_map
  end # module Schema::Elements
end

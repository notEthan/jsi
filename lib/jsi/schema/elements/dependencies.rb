# frozen_string_literal: true

module JSI
  module Schema::Elements
    DEPENDENCIES = element_map do
      Schema::Element.new(keyword: 'dependencies') do |element|
        element.add_action(:subschema) do
          #> This keyword's value MUST be an object.
          if keyword_value_hash?('dependencies')
            schema_content['dependencies'].each_pair do |property_name, dependency|
              #> Each property specifies a dependency.
              #> Each dependency value MUST be an array or a valid JSON Schema.
              if !dependency.respond_to?(:to_ary)
                cxt_yield(['dependencies', property_name])
              end
            end
          end
        end # element.add_action(:subschema)

        element.add_action(:inplace_applicate) do
          next if !keyword_value_hash?('dependencies')
          next if !instance.respond_to?(:to_hash)
          #> This keyword's value MUST be an object. Each property specifies a dependency.  Each dependency
          #> value MUST be an array or a valid JSON Schema.
          schema_content['dependencies'].each_pair do |property_name, dependency|
            if dependency.respond_to?(:to_ary)
              # noop: array-form dependencies has no inplace applicator schema
            else
              # If the dependency value is a subschema, and the dependency key is a
              # property in the instance, the entire instance must validate against
              # the dependency value.
              if instance.key?(property_name)
                inplace_subschema_applicate(['dependencies', property_name])
              end
            end
          end
        end # element.add_action(:inplace_applicate)

        element.add_action(:validate) do
              #> This keyword's value MUST be an object. Each property specifies a dependency.  Each dependency
              #> value MUST be an array or a valid JSON Schema.
              next if !keyword_value_hash?('dependencies')
              next if !instance.respond_to?(:to_hash)
              schema_content['dependencies'].each_pair do |property_name, dependency|
                if dependency.respond_to?(:to_ary)
                  # If the dependency value is an array, each element in the array, if
                  # any, MUST be a string, and MUST be unique.  If the dependency key is
                  # a property in the instance, each of the items in the dependency value
                  # must be a property that exists in the instance.
                  if instance.respond_to?(:to_hash) && instance.key?(property_name)
                    missing_required = dependency.reject { |name| instance.key?(name) }.freeze
                    validate(
                      missing_required.empty?,
                      'validation.keyword.dependencies.dependent_required.missing_property_names',
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
                  if instance.key?(property_name)
                    dependency_result = inplace_subschema_validate(['dependencies', property_name])
                    inplace_results_validate(
                      dependency_result.valid?,
                      'validation.keyword.dependencies.dependent_schema.invalid',
                      'instance object is not valid against the schema corresponding to a matched property name specified by `dependencies` value',
                      keyword: 'dependencies',
                      results: [dependency_result],
                      property_name: property_name,
                    )
                  end
                end
              end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # DEPENDENCIES = element_map
  end # module Schema::Elements
end

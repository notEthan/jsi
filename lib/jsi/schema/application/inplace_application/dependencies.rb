# frozen_string_literal: true

module JSI
  module Schema::Application::InplaceApplication::Dependencies
    # @private
    def internal_applicate_dependencies(instance, visited_refs, &block)
      if schema_content.key?('dependencies')
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
    end
  end
end

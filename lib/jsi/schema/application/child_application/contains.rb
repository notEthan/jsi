# frozen_string_literal: true

module JSI
  module Schema::Application::ChildApplication::Contains
    # @private
    def internal_applicate_contains(idx, instance, &block)
      if schema_content.key?('contains')
        contains_schema = subschema(['contains'])

        if contains_schema.instance_valid?(instance[idx])
          yield contains_schema
        end
      end
    end
  end
end

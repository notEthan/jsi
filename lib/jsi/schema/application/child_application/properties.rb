# frozen_string_literal: true

module JSI
  module Schema::Application::ChildApplication::Properties
    # @private
    def internal_applicate_properties(property_name, &block)
      apply_additional = true
      if schema_content.key?('properties') && schema_content['properties'].respond_to?(:to_hash) && schema_content['properties'].key?(property_name)
        apply_additional = false
        yield subschema(['properties', property_name])
      end
      if schema_content['patternProperties'].respond_to?(:to_hash)
        schema_content['patternProperties'].each_key do |pattern|
          if property_name.to_s =~ Regexp.new(pattern) # TODO map pattern to ruby syntax
            apply_additional = false
            yield subschema(['patternProperties', pattern])
          end
        end
      end
      if apply_additional && schema_content.key?('additionalProperties')
        yield subschema(['additionalProperties'])
      end
    end
  end
end

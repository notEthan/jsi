# frozen_string_literal: true

module JSI
  module Schema::Application::ChildApplication::Properties
    # @private
    def internal_applicate_properties(property_name, instance, &block)
    if instance.respond_to?(:to_hash)
      apply_additional = true
      if keyword?('properties') && schema_content['properties'].respond_to?(:to_hash) && schema_content['properties'].key?(property_name)
        apply_additional = false
        yield subschema(['properties', property_name])
      end
      if keyword?('patternProperties') && schema_content['patternProperties'].respond_to?(:to_hash)
        schema_content['patternProperties'].each_key do |pattern|
          if pattern.respond_to?(:to_str) && property_name.to_s =~ Regexp.new(pattern) # TODO map pattern to ruby syntax
            apply_additional = false
            yield subschema(['patternProperties', pattern])
          end
        end
      end
      if apply_additional && keyword?('additionalProperties')
        yield subschema(['additionalProperties'])
      end
    end # if instance.respond_to?(:to_hash)
    end
  end
end

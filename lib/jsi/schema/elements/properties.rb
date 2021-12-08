# frozen_string_literal: true

module JSI
  module Schema::Elements
    PROPERTIES = element_map do
      Schema::Element.new do |element|
        element.add_action(:child_applicate) do
    if instance.respond_to?(:to_hash)
      apply_additional = true
      if keyword?('properties') && schema_content['properties'].respond_to?(:to_hash) && schema_content['properties'].key?(token)
        apply_additional = false
        cxt_yield(subschema(['properties', token]))
      end
      if keyword?('patternProperties') && schema_content['patternProperties'].respond_to?(:to_hash)
        schema_content['patternProperties'].each_key do |pattern|
          if pattern.respond_to?(:to_str) && token.to_s =~ Regexp.new(pattern) # TODO map pattern to ruby syntax
            apply_additional = false
            cxt_yield(subschema(['patternProperties', pattern]))
          end
        end
      end
      if apply_additional && keyword?('additionalProperties')
        cxt_yield(subschema(['additionalProperties']))
      end
    end # if instance.respond_to?(:to_hash)
        end # element.add_action(:child_applicate)
      end # Schema::Element.new
    end # PROPERTIES = element_map
  end # module Schema::Elements
end

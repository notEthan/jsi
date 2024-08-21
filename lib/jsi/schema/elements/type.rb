# frozen_string_literal: true

module JSI
  module Schema::Elements
    #> String values MUST be one of the six primitive types
    #> ("null", "boolean", "object", "array", "number", or "string"),
    #> or "integer"
    instance_types = {
      'null' => proc { instance == nil },
      'boolean' => proc { instance == true || instance == false },
      'object' => proc { instance.respond_to?(:to_hash) },
      'array' => proc { instance.respond_to?(:to_ary) },
      'string' => proc { instance.respond_to?(:to_str) },
      'number' => proc { instance.is_a?(Numeric) },
      'integer' => proc { internal_integer?(instance) },
    }.freeze

    TYPE = element_map do
      Schema::Element.new do |element|
        element.add_action(:validate) do
      if keyword?('type')
        value = schema_content['type']
        # The value of this keyword MUST be either a string or an array. If it is an array, elements of
        # the array MUST be strings and MUST be unique.
          types = value.respond_to?(:to_ary) ? value : [value]
          matched_type = types.any? do |type|
              if instance_types.key?(type)
                instance_exec(&instance_types[type])
              else
                false
              end
          end
          validate(
            matched_type,
            'validation.keyword.type.not_match',
            'instance type does not match `type` value',
            keyword: 'type',
          )
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # TYPE = element_map
  end # module Schema::Elements
end

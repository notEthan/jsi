# frozen_string_literal: true

module JSI
  module Schema::Elements
    MAX_PROPERTIES = element_map do
      Schema::Element.new do |element|
        element.add_action(:validate) do
      if keyword?('maxProperties')
        value = schema_content['maxProperties']
        # The value of this keyword MUST be a non-negative integer.
        if internal_integer?(value) && value >= 0
          if instance.respond_to?(:to_hash)
            # An object instance is valid against "maxProperties" if its number of properties is less than, or equal to, the value of this keyword.
            validate(
              instance.size <= value,
              "instance object properties count is greater than `maxProperties` value",
              keyword: 'maxProperties',
            )
          end
        else
          schema_error('`maxProperties` is not a non-negative integer', 'maxProperties')
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # MAX_PROPERTIES = element_map
  end # module Schema::Elements

  module Schema::Elements
    MIN_PROPERTIES = element_map do
      Schema::Element.new do |element|
        element.add_action(:validate) do
      if keyword?('minProperties')
        value = schema_content['minProperties']
        # The value of this keyword MUST be a non-negative integer.
        if internal_integer?(value) && value >= 0
          if instance.respond_to?(:to_hash)
            # An object instance is valid against "minProperties" if its number of properties is greater than, or equal to, the value of this keyword.
            validate(
              instance.size >= value,
              "instance object properties count is less than `minProperties` value",
              keyword: 'minProperties',
            )
          end
        else
          schema_error('`minProperties` is not a non-negative integer', 'minProperties')
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # MIN_PROPERTIES = element_map
  end # module Schema::Elements
end

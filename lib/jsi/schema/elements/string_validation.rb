# frozen_string_literal: true

module JSI
  module Schema::Elements
    MAX_LENGTH = element_map do
      Schema::Element.new do |element|
        element.add_action(:validate) do
      if keyword?('maxLength')
        value = schema_content['maxLength']
        # The value of this keyword MUST be a non-negative integer.
        if internal_integer?(value) && value >= 0
          if instance.respond_to?(:to_str)
            # A string instance is valid against this keyword if its length is less than, or equal to, the
            # value of this keyword.
            validate(
              instance.to_str.length <= value,
              "instance string length is greater than `maxLength` value",
              keyword: 'maxLength',
            )
          end
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # MAX_LENGTH = element_map
  end # module Schema::Elements

  module Schema::Elements
    MIN_LENGTH = element_map do
      Schema::Element.new do |element|
        element.add_action(:validate) do
      if keyword?('minLength')
        value = schema_content['minLength']
        # The value of this keyword MUST be a non-negative integer.
        if internal_integer?(value) && value >= 0
          if instance.respond_to?(:to_str)
            # A string instance is valid against this keyword if its length is greater than, or equal to, the
            # value of this keyword.
            validate(
              instance.to_str.length >= value,
              "instance string length is less than `minLength` value",
              keyword: 'minLength',
            )
          end
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # MIN_LENGTH = element_map
  end # module Schema::Elements
end

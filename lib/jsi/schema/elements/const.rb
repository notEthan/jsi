# frozen_string_literal: true

module JSI
  module Schema::Elements
    CONST = element_map do
      Schema::Element.new do |element|
        element.add_action(:validate) do
      if keyword?('const')
        value = schema_content['const']
        # The value of this keyword MAY be of any type, including null.
        # An instance validates successfully against this keyword if its value is equal to the value of
        # the keyword.
        validate(
          instance == value,
          'instance is not equal to `const` value',
          keyword: 'const',
        )
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # CONST = element_map
  end # module Schema::Elements
end

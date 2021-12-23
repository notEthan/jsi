# frozen_string_literal: true

module JSI
  module Schema::Elements
    MAX_ITEMS = element_map do
      Schema::Element.new do |element|
        element.add_action(:validate) do
      if keyword?('maxItems')
        value = schema_content['maxItems']
        # The value of this keyword MUST be a non-negative integer.
        if internal_integer?(value) && value >= 0
          if instance.respond_to?(:to_ary)
            # An array instance is valid against "maxItems" if its size is less than, or equal to, the value of this keyword.
            validate(
              instance.to_ary.size <= value,
              'instance array size is greater than `maxItems` value',
              keyword: 'maxItems',
            )
          end
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # MAX_ITEMS = element_map
  end # module Schema::Elements

  module Schema::Elements
    MIN_ITEMS = element_map do
      Schema::Element.new do |element|
        element.add_action(:validate) do
      if keyword?('minItems')
        value = schema_content['minItems']
        # The value of this keyword MUST be a non-negative integer.
        if internal_integer?(value) && value >= 0
          if instance.respond_to?(:to_ary)
            # An array instance is valid against "minItems" if its size is greater than, or equal to, the value of this keyword.
            validate(
              instance.to_ary.size >= value,
              'instance array size is less than `minItems` value',
              keyword: 'minItems',
            )
          end
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # MIN_ITEMS = element_map
  end # module Schema::Elements

  module Schema::Elements
    UNIQUE_ITEMS = element_map do
      Schema::Element.new do |element|
        element.add_action(:validate) do
      if keyword?('uniqueItems')
        value = schema_content['uniqueItems']
        # The value of this keyword MUST be a boolean.
        if value == true
          if instance.respond_to?(:to_ary)
            # If it has boolean value true, the instance validates successfully if all of its elements are unique.
            validate(
              instance.uniq.size == instance.size,
              "instance array items are not unique with `uniqueItems` = true",
              keyword: 'uniqueItems',
            )
          end
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # UNIQUE_ITEMS = element_map
  end # module Schema::Elements
end

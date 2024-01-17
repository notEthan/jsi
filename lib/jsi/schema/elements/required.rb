# frozen_string_literal: true

module JSI
  module Schema::Elements
    REQUIRED = element_map do
      Schema::Element.new do |element|
        element.add_action(:validate) do
      if keyword?('required')
        value = schema_content['required']
        # The value of this keyword MUST be an array. Elements of this array, if any, MUST be strings, and MUST be unique.
        if value.respond_to?(:to_ary)
          if instance.respond_to?(:to_hash)
            # An object instance is valid against this keyword if every item in the array is the name of a property in the instance.
            missing_required = value.reject { |property_name| instance.key?(property_name) }.freeze
            validate(
              missing_required.empty?,
              'instance object does not contain all property names specified by `required` value',
              keyword: 'required',
              missing_required_property_names: missing_required,
            )
          end
        else
          schema_error('`required` is not an array', 'required')
        end
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # REQUIRED = element_map
  end # module Schema::Elements
end

# frozen_string_literal: true

module JSI
  module Schema::Elements
    NOT = element_map do
      Schema::Element.new do |element|
        element.add_action(:validate) do
      if keyword?('not')
        # This keyword's value MUST be a valid JSON Schema.
        # An instance is valid against this keyword if it fails to validate successfully against the schema
        # defined by this keyword.
        not_valid = inplace_subschema_validate(['not']).valid?
        validate(
          !not_valid,
          'instance is valid against the schema specified as `not` value',
          keyword: 'not',
        )
      end
        end # element.add_action(:validate)
      end # Schema::Element.new
    end # NOT = element_map
  end # module Schema::Elements
end

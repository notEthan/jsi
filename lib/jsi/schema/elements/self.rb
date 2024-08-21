# frozen_string_literal: true

module JSI
  module Schema::Elements
    SELF = element_map do
      Schema::Element.new do |element|
        element.add_action(:inplace_applicate) do
          inplace_schema_applicate(schema)
        end

        element.add_action(:validate) do
          #> boolean schemas are equivalent to the following behaviors:
          #>
          #> true: Always passes validation, as if the empty schema {}
          #>
          #> false: Always fails validation, as if the schema { "not":{} }
          if schema_content == false
            validate(false, 'validation.false_schema', "instance is not valid against `false` schema")
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module JSI
  module Schema::Elements
    DEFINITIONS = element_map do |keyword: |
      Schema::Element.new(keyword: keyword) do |element|
        element.add_action(:subschema) do
          #> This keyword's value MUST be an object.
          if keyword_value_hash?(keyword)
            schema_content[keyword].each_key do |property_name|
              #> Each member value of this object MUST be a valid JSON Schema.
              cxt_yield([keyword, property_name])
            end
          end
        end # element.add_action(:subschema)
      end
    end
  end
end

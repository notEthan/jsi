# frozen_string_literal: true

module JSI
  module Schema::Elements
    CONTENT_SCHEMA = element_map do
      Schema::Element.new(keyword: 'contentSchema') do |element|
        element.add_action(:subschema) do
          if keyword?('contentSchema')
            #> The value of this property MUST be a valid JSON schema.
            cxt_yield(['contentSchema'])
          end
        end # element.add_action(:subschema)
      end # Schema::Element.new
    end # CONTENT_SCHEMA = element_map
  end # module Schema::Elements
end

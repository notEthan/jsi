# frozen_string_literal: true

module JSI
  module Schema::Elements
    DEFAULT = element_map do
      Schema::Element.new(keyword: 'default') do |element|
        element.add_action(:default) { cxt_yield(schema_content['default']) if keyword?('default') }
      end # Schema::Element.new
    end # DEFAULT = element_map
  end # module Schema::Elements
end

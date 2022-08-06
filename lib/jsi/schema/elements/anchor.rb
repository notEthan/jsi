# frozen_string_literal: true

module JSI
  module Schema::Elements
    ANCHOR = element_map do
      Schema::Element.new(keyword: '$anchor') do |element|
        element.add_action(:anchor) { cxt_yield(schema_content['$anchor']) if keyword_value_str?('$anchor') }
      end
    end
  end
end

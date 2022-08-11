# frozen_string_literal: true

module JSI
  module Schema::Elements
    ID = element_map do |keyword: , fragment_is_anchor: |
      Schema::Element.new do |element|
        element.add_action(:id) { cxt_yield(schema_content[keyword]) if keyword_value_str?(keyword) }
      end
    end
  end
end

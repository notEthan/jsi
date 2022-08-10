# frozen_string_literal: true

module JSI
  module Schema::Elements
    ANCHOR = element_map do |keyword: , actions: |
      Schema::Element.new(keyword: keyword) do |element|
        actions.each do |action|
          element.add_action(action) { cxt_yield(schema_content[keyword]) if keyword_value_str?(keyword) }
        end
      end
    end
  end
end

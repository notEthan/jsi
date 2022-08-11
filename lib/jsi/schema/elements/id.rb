# frozen_string_literal: true

module JSI
  module Schema::Elements
    ID = element_map do |keyword: , fragment_is_anchor: |
      Schema::Element.new do |element|
        element.add_action(:id) { cxt_yield(schema_content[keyword]) if keyword_value_str?(keyword) }

        if fragment_is_anchor
          element.add_action(:anchor) do
            next if !keyword_value_str?(keyword)
            id_fragment = Util.uri(schema_content[keyword]).fragment
            if id_fragment && !id_fragment.empty?
              cxt_yield(id_fragment)
            end
          end
        end
      end
    end
  end
end

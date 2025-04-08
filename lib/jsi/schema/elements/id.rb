# frozen_string_literal: true

module JSI
  module Schema::Elements
    ID = element_map do |keyword: , fragment_is_anchor: |
      Schema::Element.new(keyword: keyword) do |element|
        element.add_action(:id) { cxt_yield(schema_content[keyword]) if keyword_value_str?(keyword) }

        element.add_action(:id_without_fragment) do
          next if !keyword_value_str?(keyword)
          id_without_fragment = Util.uri(schema_content[keyword]).merge(fragment: nil)

          if !id_without_fragment.empty?
            cxt_yield(id_without_fragment)
          end
        end

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

# frozen_string_literal: true

module JSI
  module Schema::Elements
    ID = element_map do |keyword: , fragment_is_anchor: |
      Schema::Element.new(keyword: keyword) do |element|
        element.add_action(:id) { cxt_yield(schema_content[keyword]) if keyword_value_str?(keyword) }

        element.add_action(:id_without_fragment) do
          next if !keyword_value_str?(keyword)
          id_uri = Util.uri(schema_content[keyword])
          if fragment_is_anchor
            if id_uri.merge(fragment: nil).empty?
              # fragment-only id is just an anchor
              # e.g. #foo
              # (noop)
            elsif id_uri.fragment == nil
              # no fragment
              # e.g. http://localhost:1234/bar
              cxt_yield(id_uri)
            elsif id_uri.fragment == ''
              # empty fragment
              # e.g. http://json-schema.org/draft-07/schema#
              cxt_yield(id_uri.merge(fragment: nil).freeze)
            elsif schema.jsi_schema_base_uri && schema.jsi_schema_base_uri.join(id_uri).merge(fragment: nil) == schema.jsi_schema_base_uri
              # the id, resolved against the base uri, consists of the base uri plus an anchor fragment.
              # so there's no non-fragment id.
              # e.g. base uri is http://localhost:1234/bar
              #        and id is http://localhost:1234/bar#foo
              # (noop)
            else
              # e.g. http://localhost:1234/bar#foo
              cxt_yield(id_uri.merge(fragment: nil).freeze)
            end
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

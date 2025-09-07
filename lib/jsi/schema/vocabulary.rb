# frozen_string_literal: true

module JSI
  module Schema
    class Vocabulary
      include(Util::Pretty)

      # @param id [#to_str, nil]
      # @param elements [Enumerable<Schema::Element>]
      def initialize(id: nil, elements: )
        @id = Util.uri(id, nnil: false, yabs: true, ynorm: true)
        raise(TypeError, "elements: #{elements}") unless elements.all? { |e| e.is_a?(Schema::Element) }
        @elements = Set.new(elements).freeze

        freeze
      end

      # @return [URI, nil]
      attr_reader(:id)

      # @return [Set<Schema::Element>]
      attr_reader(:elements)

      # @param q
      def pretty_print(q)
        if id
          jsi_pp_object_group(q, [self.class.name, -"id: <#{id}>"])
        else
          jsi_pp_object_group(q) do
            q.seplist(elements) { |e| q.pp(e) }
          end
        end
      end
    end
  end
end

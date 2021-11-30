# frozen_string_literal: true

module JSI
  module Schema
    class Vocabulary
      # @param elements [Enumerable<Schema::Element>]
      def initialize(elements: )
        raise(TypeError, "elements: #{elements}") unless elements.all? { |e| e.is_a?(Schema::Element) }
        @elements = Set.new(elements).freeze

        freeze
      end

      # @return [Set<Schema::Element>]
      attr_reader(:elements)
    end
  end
end

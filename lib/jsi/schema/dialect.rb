# frozen_string_literal: true

module JSI
  module Schema
    class Dialect
      # @param vocabularies [Enumerable<Schema::Vocabulary>]
      def initialize(vocabularies: )
        @vocabularies = Set.new(vocabularies).freeze
        @elements = vocabularies.map(&:elements).inject(Set.new, &:merge).freeze

        freeze
      end

      # @return [Set<Schema::Vocabulary>]
      attr_reader(:vocabularies)

      # @return [Set<Schema::Element>]
      attr_reader(:elements)
    end
  end
end

# frozen_string_literal: true

module JSI
  module Schema
    class Dialect
      # @param vocabularies [Enumerable<Schema::Vocabulary>]
      def initialize(vocabularies: )
        @vocabularies = Set.new(vocabularies).freeze

        freeze
      end

      # @return [Set<Schema::Vocabulary>]
      attr_reader(:vocabularies)
    end
  end
end

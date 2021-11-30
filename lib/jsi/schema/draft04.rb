# frozen_string_literal: true

module JSI
  module Schema
    module Draft04
      include OldId
      include IdWithAnchor
      include IntegerDisallows0Fraction
      include Schema::Application::Draft04
      include Schema::Validation::Draft04

      VOCABULARY = Vocabulary.new(
        elements: [
        ],
      )

      DIALECT = Dialect.new(
        vocabularies: [VOCABULARY],
      )

      def dialect
        DIALECT
      end
    end
  end
end

# frozen_string_literal: true

module JSI
  module Schema
    module Draft07
      include BigMoneyId
      include IdWithAnchor
      include IntegerAllows0Fraction
      include Schema::Application::Draft07
      include Schema::Validation::Draft07

      VOCABULARY = Vocabulary.new(
        elements: [
          # draft-handrews-json-schema-01 8.  Base URI and Dereferencing

          # draft-handrews-json-schema-01 8.3.  Schema References With "$ref"
          Schema::Elements::REF[],
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

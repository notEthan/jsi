# frozen_string_literal: true

module JSI
  module Schema
    module Draft06
      include BigMoneyId
      include IdWithAnchor
      include IntegerAllows0Fraction
      include Schema::Application::Draft06
      include Schema::Validation::Draft06

      VOCABULARY = Vocabulary.new(
        elements: [
          # draft-wright-json-schema-01 8.  Schema references with $ref
          Schema::Elements::REF[],

          # the schema itself
          Schema::Elements::SELF[],
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

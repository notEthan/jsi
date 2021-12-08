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

          # draft-wright-json-schema-validation-01 6.  Validation keywords

          # draft-wright-json-schema-validation-01 6.9.  items
          # draft-wright-json-schema-validation-01 6.10.  additionalItems
          Schema::Elements::ITEMS[],

          # draft-wright-json-schema-validation-01 6.14.  contains
          Schema::Elements::CONTAINS[],

          # draft-wright-json-schema-validation-01 6.18.  properties
          # draft-wright-json-schema-validation-01 6.19.  patternProperties
          # draft-wright-json-schema-validation-01 6.20.  additionalProperties
          Schema::Elements::PROPERTIES[],

          # draft-wright-json-schema-validation-01 6.21.  dependencies
          Schema::Elements::DEPENDENCIES[],

          # draft-wright-json-schema-validation-01 6.26.  allOf
          Schema::Elements::ALL_OF[],

          # draft-wright-json-schema-validation-01 6.27.  anyOf
          Schema::Elements::ANY_OF[],

          # draft-wright-json-schema-validation-01 6.28.  oneOf
          Schema::Elements::ONE_OF[],
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

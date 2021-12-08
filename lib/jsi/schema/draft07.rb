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

          # the schema itself
          Schema::Elements::SELF[],

          # draft-handrews-json-schema-validation-01 6.  Validation Keywords

          # draft-handrews-json-schema-validation-01 6.4.  Validation Keywords for Arrays

          # draft-handrews-json-schema-validation-01 6.4.1.  items
          # draft-handrews-json-schema-validation-01 6.4.2.  additionalItems
          Schema::Elements::ITEMS[],

          # draft-handrews-json-schema-validation-01 6.4.6.  contains
          Schema::Elements::CONTAINS[],

          # draft-handrews-json-schema-validation-01 6.5.  Validation Keywords for Objects

          # draft-handrews-json-schema-validation-01 6.5.4.  properties
          # draft-handrews-json-schema-validation-01 6.5.5.  patternProperties
          # draft-handrews-json-schema-validation-01 6.5.6.  additionalProperties
          Schema::Elements::PROPERTIES[],

          # draft-handrews-json-schema-validation-01 6.5.7.  dependencies
          Schema::Elements::DEPENDENCIES[],

          # draft-handrews-json-schema-validation-01 6.6.  Keywords for Applying Subschemas Conditionally

          # draft-handrews-json-schema-validation-01 6.6.1.  if
          # draft-handrews-json-schema-validation-01 6.6.2.  then
          # draft-handrews-json-schema-validation-01 6.6.3.  else
          Schema::Elements::IF_THEN_ELSE[],

          # draft-handrews-json-schema-validation-01 6.7.  Keywords for Applying Subschemas With Boolean Logic

          # draft-handrews-json-schema-validation-01 6.7.1.  allOf
          Schema::Elements::ALL_OF[],

          # draft-handrews-json-schema-validation-01 6.7.2.  anyOf
          Schema::Elements::ANY_OF[],

          # draft-handrews-json-schema-validation-01 6.7.3.  oneOf
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

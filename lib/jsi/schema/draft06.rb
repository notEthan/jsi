# frozen_string_literal: true

module JSI
  module Schema
    module Draft06
      include BigMoneyId
      include IdWithAnchor
      include IntegerAllows0Fraction

      VOCABULARY = Vocabulary.new(
        elements: [
          # the schema itself
          Schema::Elements::SELF[],

          # draft-wright-json-schema-01 7.  The "$schema" keyword
          Schema::Elements::XSCHEMA[],

          # draft-wright-json-schema-01 8.  Schema references with $ref
          Schema::Elements::REF[exclusive: true],

          # draft-wright-json-schema-01 9.  Base URI and dereferencing

          # draft-wright-json-schema-01 9.2.  The "$id" keyword
          Schema::Elements::ID[keyword: '$id'],

          # draft-wright-json-schema-validation-01 6.  Validation keywords

          # draft-wright-json-schema-validation-01 6.1.  multipleOf
          Schema::Elements::MULTIPLE_OF[],

          # draft-wright-json-schema-validation-01 6.2.  maximum
          Schema::Elements::MAXIMUM[],

          # draft-wright-json-schema-validation-01 6.3.  exclusiveMaximum
          Schema::Elements::EXCLUSIVE_MAXIMUM[],

          # draft-wright-json-schema-validation-01 6.4.  minimum
          Schema::Elements::MINIMUM[],

          # draft-wright-json-schema-validation-01 6.5.  exclusiveMinimum
          Schema::Elements::EXCLUSIVE_MINIMUM[],

          # draft-wright-json-schema-validation-01 6.6.  maxLength
          Schema::Elements::MAX_LENGTH[],

          # draft-wright-json-schema-validation-01 6.7.  minLength
          Schema::Elements::MIN_LENGTH[],

          # draft-wright-json-schema-validation-01 6.8.  pattern
          Schema::Elements::PATTERN[],

          # draft-wright-json-schema-validation-01 6.9.  items
          # draft-wright-json-schema-validation-01 6.10.  additionalItems
          Schema::Elements::ITEMS[],

          # draft-wright-json-schema-validation-01 6.11.  maxItems
          Schema::Elements::MAX_ITEMS[],

          # draft-wright-json-schema-validation-01 6.12.  minItems
          Schema::Elements::MIN_ITEMS[],

          # draft-wright-json-schema-validation-01 6.13.  uniqueItems
          Schema::Elements::UNIQUE_ITEMS[],

          # draft-wright-json-schema-validation-01 6.14.  contains
          Schema::Elements::CONTAINS[],

          # draft-wright-json-schema-validation-01 6.15.  maxProperties
          Schema::Elements::MAX_PROPERTIES[],

          # draft-wright-json-schema-validation-01 6.16.  minProperties
          Schema::Elements::MIN_PROPERTIES[],

          # draft-wright-json-schema-validation-01 6.17.  required
          Schema::Elements::REQUIRED[],

          # draft-wright-json-schema-validation-01 6.18.  properties
          # draft-wright-json-schema-validation-01 6.19.  patternProperties
          # draft-wright-json-schema-validation-01 6.20.  additionalProperties
          Schema::Elements::PROPERTIES[],

          # draft-wright-json-schema-validation-01 6.21.  dependencies
          Schema::Elements::DEPENDENCIES[],

          # draft-wright-json-schema-validation-01 6.22.  propertyNames
          Schema::Elements::PROPERTY_NAMES[],

          # draft-wright-json-schema-validation-01 6.23.  enum
          Schema::Elements::ENUM[],

          # draft-wright-json-schema-validation-01 6.24.  const
          Schema::Elements::CONST[],

          # draft-wright-json-schema-validation-01 6.25.  type
          Schema::Elements::TYPE[],

          # draft-wright-json-schema-validation-01 6.26.  allOf
          Schema::Elements::ALL_OF[],

          # draft-wright-json-schema-validation-01 6.27.  anyOf
          Schema::Elements::ANY_OF[],

          # draft-wright-json-schema-validation-01 6.28.  oneOf
          Schema::Elements::ONE_OF[],

          # draft-wright-json-schema-validation-01 6.29.  not
          Schema::Elements::NOT[],

          # draft-wright-json-schema-validation-01 7.  Metadata keywords

          # draft-wright-json-schema-validation-01 7.1.  definitions
          Schema::Elements::DEFINITIONS[keyword: 'definitions'],

          # draft-wright-json-schema-validation-01 7.2.  "title" and "description"
          Schema::Elements::INFO_STRING[keyword: 'title'],
          Schema::Elements::INFO_STRING[keyword: 'description'],

          # draft-wright-json-schema-validation-01 7.3.  "default"
          Schema::Elements::DEFAULT[],
        ],
      )

      DIALECT = Dialect.new(
        id: "http://json-schema.org/draft-06/schema",
        vocabularies: [VOCABULARY],
      )

      def dialect
        DIALECT
      end
    end
  end
end

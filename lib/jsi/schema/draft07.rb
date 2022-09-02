# frozen_string_literal: true

module JSI
  module Schema
    module Draft07
      include IntegerAllows0Fraction

      VOCABULARY = Vocabulary.new(
        elements: [
          # the schema itself
          Schema::Elements::SELF[],

          # draft-handrews-json-schema-01 8.  Base URI and Dereferencing

          # draft-handrews-json-schema-01 8.2.  The "$id" Keyword
          Schema::Elements::ID[keyword: '$id', fragment_is_anchor: true],

          # draft-handrews-json-schema-01 8.3.  Schema References With "$ref"
          Schema::Elements::REF[exclusive: true],

          # draft-handrews-json-schema-validation-01 6.  Validation Keywords

          # draft-handrews-json-schema-validation-01 6.1.  Validation Keywords for Any Instance Type

          # draft-handrews-json-schema-validation-01 6.1.1.  type
          Schema::Elements::TYPE[],

          # draft-handrews-json-schema-validation-01 6.1.2.  enum
          Schema::Elements::ENUM[],

          # draft-handrews-json-schema-validation-01 6.1.3.  const
          Schema::Elements::CONST[],

          # draft-handrews-json-schema-validation-01 6.2.  Validation Keywords for Numeric Instances (number and integer)

          # draft-handrews-json-schema-validation-01 6.2.1.  multipleOf
          Schema::Elements::MULTIPLE_OF[],

          # draft-handrews-json-schema-validation-01 6.2.2.  maximum
          Schema::Elements::MAXIMUM[],

          # draft-handrews-json-schema-validation-01 6.2.3.  exclusiveMaximum
          Schema::Elements::EXCLUSIVE_MAXIMUM[],

          # draft-handrews-json-schema-validation-01 6.2.4.  minimum
          Schema::Elements::MINIMUM[],

          # draft-handrews-json-schema-validation-01 6.2.5.  exclusiveMinimum
          Schema::Elements::EXCLUSIVE_MINIMUM[],

          # draft-handrews-json-schema-validation-01 6.3.  Validation Keywords for Strings

          # draft-handrews-json-schema-validation-01 6.3.1.  maxLength
          Schema::Elements::MAX_LENGTH[],

          # draft-handrews-json-schema-validation-01 6.3.2.  minLength
          Schema::Elements::MIN_LENGTH[],

          # draft-handrews-json-schema-validation-01 6.3.3.  pattern
          Schema::Elements::PATTERN[],

          # draft-handrews-json-schema-validation-01 6.4.  Validation Keywords for Arrays

          # draft-handrews-json-schema-validation-01 6.4.1.  items
          # draft-handrews-json-schema-validation-01 6.4.2.  additionalItems
          Schema::Elements::ITEMS[],

          # draft-handrews-json-schema-validation-01 6.4.3.  maxItems
          Schema::Elements::MAX_ITEMS[],

          # draft-handrews-json-schema-validation-01 6.4.4.  minItems
          Schema::Elements::MIN_ITEMS[],

          # draft-handrews-json-schema-validation-01 6.4.5.  uniqueItems
          Schema::Elements::UNIQUE_ITEMS[],

          # draft-handrews-json-schema-validation-01 6.4.6.  contains
          Schema::Elements::CONTAINS[],

          # draft-handrews-json-schema-validation-01 6.5.  Validation Keywords for Objects

          # draft-handrews-json-schema-validation-01 6.5.1.  maxProperties
          Schema::Elements::MAX_PROPERTIES[],

          # draft-handrews-json-schema-validation-01 6.5.2.  minProperties
          Schema::Elements::MIN_PROPERTIES[],

          # draft-handrews-json-schema-validation-01 6.5.3.  required
          Schema::Elements::REQUIRED[],

          # draft-handrews-json-schema-validation-01 6.5.4.  properties
          # draft-handrews-json-schema-validation-01 6.5.5.  patternProperties
          # draft-handrews-json-schema-validation-01 6.5.6.  additionalProperties
          Schema::Elements::PROPERTIES[],

          # draft-handrews-json-schema-validation-01 6.5.7.  dependencies
          Schema::Elements::DEPENDENCIES[],

          # draft-handrews-json-schema-validation-01 6.5.8.  propertyNames
          Schema::Elements::PROPERTY_NAMES[],

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

          # draft-handrews-json-schema-validation-01 6.7.4.  not
          Schema::Elements::NOT[],

          # draft-handrews-json-schema-validation-01 7.  Semantic Validation With "format"
          # TODO

          # draft-handrews-json-schema-validation-01 9.  Schema Re-Use With "definitions"
          Schema::Elements::DEFINITIONS[keyword: 'definitions'],

          # draft-handrews-json-schema-validation-01 10.  Schema Annotations

          # draft-handrews-json-schema-validation-01 10.1.  "title" and "description"
          # TODO

          # draft-handrews-json-schema-validation-01 10.2.  "default"
          Schema::Elements::DEFAULT[],

          # draft-handrews-json-schema-validation-01 10.3.  "readOnly" and "writeOnly"
          # TODO

          # draft-handrews-json-schema-validation-01 10.4.  "examples"
          # TODO
        ],
      )

      DIALECT = Dialect.new(
        id: "http://json-schema.org/draft-07/schema",
        vocabularies: [VOCABULARY],
      )

      def dialect
        DIALECT
      end
    end
  end
end

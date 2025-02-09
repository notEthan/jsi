# frozen_string_literal: true

module JSI
  module Schema
    module Draft04
      VOCABULARY = Vocabulary.new(
        elements: [
          # the schema itself
          Schema::Elements::SELF[],

          # draft-zyp-json-schema-04 6.  The "$schema" keyword
          Schema::Elements::XSCHEMA[],

          # draft-pbryan-zyp-json-ref-03
          Schema::Elements::REF[exclusive: true],

          # draft-zyp-json-schema-04 7.  URI resolution scopes and dereferencing

          # draft-zyp-json-schema-04 7.2.  URI resolution scope alteration with the "id" keyword
          Schema::Elements::ID[keyword: 'id', fragment_is_anchor: true],

          # draft-fge-json-schema-validation-00 5.  Validation keywords sorted by instance types

          # draft-fge-json-schema-validation-00 5.1.  Validation keywords for numeric instances (number and integer)

          # draft-fge-json-schema-validation-00 5.1.1.  multipleOf
          Schema::Elements::MULTIPLE_OF[],

          # draft-fge-json-schema-validation-00 5.1.2.  maximum and exclusiveMaximum
          Schema::Elements::MAXIMUM_BOOLEAN_EXCLUSIVE[],

          # draft-fge-json-schema-validation-00 5.1.3.  minimum and exclusiveMinimum
          Schema::Elements::MINIMUM_BOOLEAN_EXCLUSIVE[],

          # draft-fge-json-schema-validation-00 5.2.  Validation keywords for strings

          # draft-fge-json-schema-validation-00 5.2.1.  maxLength
          Schema::Elements::MAX_LENGTH[],

          # draft-fge-json-schema-validation-00 5.2.2.  minLength
          Schema::Elements::MIN_LENGTH[],

          # draft-fge-json-schema-validation-00 5.2.3.  pattern
          Schema::Elements::PATTERN[],

          # draft-fge-json-schema-validation-00 5.3.  Validation keywords for arrays

          # draft-fge-json-schema-validation-00 5.3.1.  additionalItems and items
          Schema::Elements::ITEMS[],

          # draft-fge-json-schema-validation-00 5.3.2.  maxItems
          Schema::Elements::MAX_ITEMS[],

          # draft-fge-json-schema-validation-00 5.3.3.  minItems
          Schema::Elements::MIN_ITEMS[],

          # draft-fge-json-schema-validation-00 5.3.4.  uniqueItems
          Schema::Elements::UNIQUE_ITEMS[],

          # draft-fge-json-schema-validation-00 5.4.  Validation keywords for objects

          # draft-fge-json-schema-validation-00 5.4.1.  maxProperties
          Schema::Elements::MAX_PROPERTIES[],

          # draft-fge-json-schema-validation-00 5.4.2.  minProperties
          Schema::Elements::MIN_PROPERTIES[],

          # draft-fge-json-schema-validation-00 5.4.3.  required
          Schema::Elements::REQUIRED[],

          # draft-fge-json-schema-validation-00 5.4.4.  additionalProperties, properties and patternProperties
          Schema::Elements::PROPERTIES[],

          # draft-fge-json-schema-validation-00 5.4.5.  dependencies
          Schema::Elements::DEPENDENCIES[],

          # draft-fge-json-schema-validation-00 5.5.  Validation keywords for any instance type

          # draft-fge-json-schema-validation-00 5.5.1.  enum
          Schema::Elements::ENUM[],

          # draft-fge-json-schema-validation-00 5.5.2.  type
          Schema::Elements::TYPE[],

          # draft-fge-json-schema-validation-00 5.5.3.  allOf
          Schema::Elements::ALL_OF[],

          # draft-fge-json-schema-validation-00 5.5.4.  anyOf
          Schema::Elements::ANY_OF[],

          # draft-fge-json-schema-validation-00 5.5.5.  oneOf
          Schema::Elements::ONE_OF[],

          # draft-fge-json-schema-validation-00 5.5.6.  not
          Schema::Elements::NOT[],

          # draft-fge-json-schema-validation-00 5.5.7.  definitions
          Schema::Elements::DEFINITIONS[keyword: 'definitions'],

          # draft-fge-json-schema-validation-00 6. Metadata keywords

          # draft-fge-json-schema-validation-00 6.1.  "title" and "description"
          Schema::Elements::INFO_STRING[keyword: 'title'],
          Schema::Elements::INFO_STRING[keyword: 'description'],

          # draft-fge-json-schema-validation-00 6.2.  "default"
          Schema::Elements::DEFAULT[],

          # draft-fge-json-schema-validation-00 7.  Semantic validation with "format"
          Schema::Elements::FORMAT[],
        ],
      )

      DIALECT = Dialect.new(
        id: "http://json-schema.org/draft-04/schema",
        vocabularies: [VOCABULARY],
        integer_disallows_0_fraction: true,
      )
    end
  end
end

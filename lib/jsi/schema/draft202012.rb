# frozen_string_literal: true

module JSI
  module Schema::Draft202012
    module Vocab
    end

    # draft-bhutton-json-schema-01 8.  The JSON Schema Core Vocabulary
    #
    # The current URI for the Core vocabulary is:
    # https://json-schema.org/draft/2020-12/vocab/core
    #
    # The current URI for the corresponding meta-schema is:
    # https://json-schema.org/draft/2020-12/meta/core
    Vocab::CORE = Schema::Vocabulary.new(
      id: "https://json-schema.org/draft/2020-12/vocab/core",
      elements: [
        Schema::Elements::SELF[],

        # draft-bhutton-json-schema-01 8.1.1.  The "$schema" Keyword
        Schema::Elements::XSCHEMA[],

        # draft-bhutton-json-schema-01 8.1.2.  The "$vocabulary" Keyword
        Schema::Elements::XVOCABULARY[],

        # draft-bhutton-json-schema-01 8.2.1.  The "$id" Keyword
        Schema::Elements::ID[keyword: '$id', fragment_is_anchor: false],

        # draft-bhutton-json-schema-01 8.2.2.  Defining location-independent identifiers
        Schema::Elements::ANCHOR[keyword: '$anchor', actions: [:anchor]],
        Schema::Elements::ANCHOR[keyword: '$dynamicAnchor', actions: [:anchor, :dynamicAnchor]],

        # draft-bhutton-json-schema-01 8.2.3.  Schema References

        # draft-bhutton-json-schema-01 8.2.3.1.  Direct References with "$ref"
        Schema::Elements::REF[exclusive: false],

        # draft-bhutton-json-schema-01 8.2.3.2.  Dynamic References with "$dynamicRef"
        Schema::Elements::DYNAMIC_REF[],

        # draft-bhutton-json-schema-01 8.2.4.  Schema Re-Use With "$defs"
        Schema::Elements::DEFINITIONS[keyword: '$defs'],

        # draft-bhutton-json-schema-01 8.3.  Comments With "$comment"
        Schema::Elements::COMMENT[],
      ],
    )

    # draft-bhutton-json-schema-01 10.  A Vocabulary for Applying Subschemas
    #
    # The current URI for this vocabulary, known as the Applicator vocabulary, is:
    # https://json-schema.org/draft/2020-12/vocab/applicator
    #
    # The current URI for the corresponding meta-schema is:
    # https://json-schema.org/draft/2020-12/meta/applicator
    Vocab::APPLICATOR = Schema::Vocabulary.new(
      id: "https://json-schema.org/draft/2020-12/vocab/applicator",
      elements: [
        # draft-bhutton-json-schema-01 10.2.  Keywords for Applying Subschemas in Place
        # draft-bhutton-json-schema-01 10.2.1.  Keywords for Applying Subschemas With Logic

        # draft-bhutton-json-schema-01 10.2.1.1.  allOf
        Schema::Elements::ALL_OF[],

        # draft-bhutton-json-schema-01 10.2.1.2.  anyOf
        Schema::Elements::ANY_OF[],

        # draft-bhutton-json-schema-01 10.2.1.3.  oneOf
        Schema::Elements::ONE_OF[],

        # draft-bhutton-json-schema-01 10.2.1.4.  not
        Schema::Elements::NOT[],

        # draft-bhutton-json-schema-01 10.2.2.  Keywords for Applying Subschemas Conditionally

        # draft-bhutton-json-schema-01 10.2.2.1.  if
        # draft-bhutton-json-schema-01 10.2.2.2.  then
        # draft-bhutton-json-schema-01 10.2.2.3.  else
        Schema::Elements::IF_THEN_ELSE[],

        # draft-bhutton-json-schema-01 10.2.2.4.  dependentSchemas
        Schema::Elements::DEPENDENT_SCHEMAS[],

        # draft-bhutton-json-schema-01 10.3.  Keywords for Applying Subschemas to Child Instances
        # draft-bhutton-json-schema-01 10.3.1.  Keywords for Applying Subschemas to Arrays

        # draft-bhutton-json-schema-01 10.3.1.1.  prefixItems
        # draft-bhutton-json-schema-01 10.3.1.2.  items
        Schema::Elements::ITEMS_PREFIXED[],

        # draft-bhutton-json-schema-01 10.3.1.3.  contains
        Schema::Elements::CONTAINS_MINMAX[],

        # draft-bhutton-json-schema-01 10.3.2.  Keywords for Applying Subschemas to Objects

        # draft-bhutton-json-schema-01 10.3.2.1.  properties
        # draft-bhutton-json-schema-01 10.3.2.2.  patternProperties
        # draft-bhutton-json-schema-01 10.3.2.3.  additionalProperties
        Schema::Elements::PROPERTIES[],

        # draft-bhutton-json-schema-01 10.3.2.4.  propertyNames
        Schema::Elements::PROPERTY_NAMES[],
      ],
    )

    # draft-bhutton-json-schema-01 11.  A Vocabulary for Unevaluated Locations
    #
    # The current URI for this vocabulary, known as the Unevaluated Applicator vocabulary, is:
    # https://json-schema.org/draft/2020-12/vocab/unevaluated
    #
    # The current URI for the corresponding meta-schema is:
    # https://json-schema.org/draft/2020-12/meta/unevaluated
    Vocab::UNEVALUATED = Schema::Vocabulary.new(
      id: "https://json-schema.org/draft/2020-12/vocab/unevaluated",
      elements: [
        # draft-bhutton-json-schema-01 11.2.  unevaluatedItems
        Schema::Elements::UNEVALUATED_ITEMS[],

        # draft-bhutton-json-schema-01 11.3.  unevaluatedProperties
        Schema::Elements::UNEVALUATED_PROPERTIES[],
      ],
    )

    # draft-bhutton-json-schema-validation-01 6.  A Vocabulary for Structural Validation
    #
    # The current URI for this vocabulary, known as the Validation vocabulary, is:
    # https://json-schema.org/draft/2020-12/vocab/validation
    #
    # The current URI for the corresponding meta-schema is:
    # https://json-schema.org/draft/2020-12/meta/validation
    Vocab::VALIDATION = Schema::Vocabulary.new(
      id: "https://json-schema.org/draft/2020-12/vocab/validation",
      elements: [
        # draft-bhutton-json-schema-validation-01 6.1.  Validation Keywords for Any Instance Type

        # draft-bhutton-json-schema-validation-01 6.1.1.  type
        Schema::Elements::TYPE[],

        # draft-bhutton-json-schema-validation-01 6.1.2.  enum
        Schema::Elements::ENUM[],

        # draft-bhutton-json-schema-validation-01 6.1.3.  const
        Schema::Elements::CONST[],

        # draft-bhutton-json-schema-validation-01 6.2.  Validation Keywords for Numeric Instances (number and integer)

        # draft-bhutton-json-schema-validation-01 6.2.1.  multipleOf
        Schema::Elements::MULTIPLE_OF[],

        # draft-bhutton-json-schema-validation-01 6.2.2.  maximum
        Schema::Elements::MAXIMUM[],

        # draft-bhutton-json-schema-validation-01 6.2.3.  exclusiveMaximum
        Schema::Elements::EXCLUSIVE_MAXIMUM[],

        # draft-bhutton-json-schema-validation-01 6.2.4.  minimum
        Schema::Elements::MINIMUM[],

        # draft-bhutton-json-schema-validation-01 6.2.5.  exclusiveMinimum
        Schema::Elements::EXCLUSIVE_MINIMUM[],

        # draft-bhutton-json-schema-validation-01 6.3.  Validation Keywords for Strings

        # draft-bhutton-json-schema-validation-01 6.3.1.  maxLength
        Schema::Elements::MAX_LENGTH[],

        # draft-bhutton-json-schema-validation-01 6.3.2.  minLength
        Schema::Elements::MIN_LENGTH[],

        # draft-bhutton-json-schema-validation-01 6.3.3.  pattern
        Schema::Elements::PATTERN[],

        # draft-bhutton-json-schema-validation-01 6.4.  Validation Keywords for Arrays

        # draft-bhutton-json-schema-validation-01 6.4.1.  maxItems
        Schema::Elements::MAX_ITEMS[],

        # draft-bhutton-json-schema-validation-01 6.4.2.  minItems
        Schema::Elements::MIN_ITEMS[],

        # draft-bhutton-json-schema-validation-01 6.4.3.  uniqueItems
        Schema::Elements::UNIQUE_ITEMS[],

        # draft-bhutton-json-schema-validation-01 6.4.4.  maxContains
        # draft-bhutton-json-schema-validation-01 6.4.5.  minContains
        # (see Schema::Elements::CONTAINS_MINMAX[] - draft-bhutton-json-schema-01 10.3.1.3.  contains)

        # draft-bhutton-json-schema-validation-01 6.5.  Validation Keywords for Objects

        # draft-bhutton-json-schema-validation-01 6.5.1.  maxProperties
        Schema::Elements::MAX_PROPERTIES[],

        # draft-bhutton-json-schema-validation-01 6.5.2.  minProperties
        Schema::Elements::MIN_PROPERTIES[],

        # draft-bhutton-json-schema-validation-01 6.5.3.  required
        Schema::Elements::REQUIRED[],

        # draft-bhutton-json-schema-validation-01 6.5.4.  dependentRequired
        Schema::Elements::DEPENDENT_REQUIRED[],
      ],
    )

    # draft-bhutton-json-schema-validation-01 7.  Vocabularies for Semantic Content With "format"
    #
    # The current URI for this vocabulary, known as the Format-Annotation vocabulary, is:
    # https://json-schema.org/draft/2020-12/vocab/format-annotation
    #
    # The current URI for the corresponding meta-schema is:
    # https://json-schema.org/draft/2020-12/meta/format-annotation
    Vocab::FORMAT_ANNOTATION = Schema::Vocabulary.new(
      id: "https://json-schema.org/draft/2020-12/vocab/format-annotation",
      elements: [
        # draft-bhutton-json-schema-validation-01 7.2.1.  Format-Annotation Vocabulary
        Schema::Elements::FORMAT[],
      ],
    )

    # draft-bhutton-json-schema-validation-01 7.  Vocabularies for Semantic Content With "format"
    #
    # The URI for the Format-Assertion vocabulary, is:
    # https://json-schema.org/draft/2020-12/vocab/format-assertion
    #
    # The current URI for the corresponding meta-schema is:
    # https://json-schema.org/draft/2020-12/meta/format-assertion
    #
    # (Vocab::FORMAT_ASSERTION not implemented)


    # draft-bhutton-json-schema-validation-01 8.  A Vocabulary for the Contents of String-Encoded Data
    #
    # The current URI for this vocabulary, known as the Content vocabulary, is:
    # https://json-schema.org/draft/2020-12/vocab/content
    #
    # The current URI for the corresponding meta-schema is:
    # https://json-schema.org/draft/2020-12/meta/content
    Vocab::CONTENT = Schema::Vocabulary.new(
      id: "https://json-schema.org/draft/2020-12/vocab/content",
      elements: [
        # draft-bhutton-json-schema-validation-01 8.3.  contentEncoding
        Schema::Elements::CONTENT_ENCODING[],

        # draft-bhutton-json-schema-validation-01 8.4.  contentMediaType
        Schema::Elements::CONTENT_MEDIA_TYPE[],

        # draft-bhutton-json-schema-validation-01 8.5.  contentSchema
        Schema::Elements::CONTENT_SCHEMA[],
      ],
    )

    # draft-bhutton-json-schema-validation-01 9.  A Vocabulary for Basic Meta-Data Annotations
    #
    # The current URI for this vocabulary, known as the Meta-Data vocabulary, is:
    # https://json-schema.org/draft/2020-12/vocab/meta-data
    #
    # The current URI for the corresponding meta-schema is:
    # https://json-schema.org/draft/2020-12/meta/meta-data
    Vocab::METADATA = Schema::Vocabulary.new(
      id: "https://json-schema.org/draft/2020-12/vocab/meta-data",
      elements: [
        # draft-bhutton-json-schema-validation-01 9.1.  "title" and "description"
        Schema::Elements::INFO_STRING[keyword: 'title'],
        Schema::Elements::INFO_STRING[keyword: 'description'],

        # draft-bhutton-json-schema-validation-01 9.2.  "default"
        Schema::Elements::DEFAULT[],

        # draft-bhutton-json-schema-validation-01 9.3.  "deprecated"
        Schema::Elements::INFO_BOOL[keyword: 'deprecated'],

        # draft-bhutton-json-schema-validation-01 9.4.  "readOnly" and "writeOnly"
        Schema::Elements::INFO_BOOL[keyword: 'readOnly'],
        Schema::Elements::INFO_BOOL[keyword: 'writeOnly'],

        # draft-bhutton-json-schema-validation-01 9.5.  "examples"
        Schema::Elements::EXAMPLES[],
      ],
    )

    # Compatibility vocabulary: The specification doesn't specify these keywords,
    # but the meta-schema describes them. The test suite considers them optional.
    Vocab::COMPATIBILITY = Schema::Vocabulary.new(
      elements: [
        Schema::Elements::DEFINITIONS[keyword: 'definitions'],

        Schema::Elements::DEPENDENCIES[],
      ],
    )

    DIALECT = Schema::Dialect.new(
      id: "https://json-schema.org/draft/2020-12/schema",
      vocabularies: [
        Vocab::CORE,
        Vocab::APPLICATOR,
        Vocab::UNEVALUATED,
        Vocab::VALIDATION,
        Vocab::FORMAT_ANNOTATION,
        Vocab::CONTENT,
        Vocab::METADATA,
        Vocab::COMPATIBILITY,
      ],
    )
  end
end

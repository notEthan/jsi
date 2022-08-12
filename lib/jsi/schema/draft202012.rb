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
      elements: [
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
      elements: [
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
      elements: [
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
      elements: [
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
      elements: [
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
      elements: [
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
      elements: [
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
      ],
    )
  end
end

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
          # draft-pbryan-zyp-json-ref-03
          Schema::Elements::REF[],

          # the schema itself
          Schema::Elements::SELF[],

          # draft-fge-json-schema-validation-00 5.  Validation keywords sorted by instance types

          # draft-fge-json-schema-validation-00 5.4.  Validation keywords for objects

          # draft-fge-json-schema-validation-00 5.4.5.  dependencies
          Schema::Elements::DEPENDENCIES[],

          # draft-fge-json-schema-validation-00 5.5.  Validation keywords for any instance type

          # draft-fge-json-schema-validation-00 5.5.3.  allOf
          # draft-fge-json-schema-validation-00 5.5.4.  anyOf
          # draft-fge-json-schema-validation-00 5.5.5.  oneOf
          Schema::Elements::SOME_OF[],
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

# frozen_string_literal: true

module JSI
  module Schema::Validation::Draft06
    include Schema::Validation::Ref
    include Schema::Validation::AllOf
    include Schema::Validation::AnyOf
    include Schema::Validation::OneOf

    include Schema::Validation::Items
    include Schema::Validation::Contains
    include Schema::Validation::Properties

    include Schema::Validation::Dependencies
    # @private
    def internal_validate_keywords(result_builder)
      # json-schema 8.  Schema references with $ref
      internal_validate_ref(result_builder, throw_result: true)

      # json-schema-validation 6.9.  items
      # json-schema-validation 6.10.  additionalItems
      internal_validate_items(result_builder)

      # json-schema-validation 6.14.  contains
      internal_validate_contains(result_builder)

      # json-schema-validation 6.18.  properties
      # json-schema-validation 6.19.  patternProperties
      # json-schema-validation 6.20.  additionalProperties
      internal_validate_properties(result_builder)

      # json-schema-validation 6.21.  dependencies
      internal_validate_dependencies(result_builder)

      # json-schema-validation 6.26.  allOf
      internal_validate_allOf(result_builder)
      # json-schema-validation 6.27.  anyOf
      internal_validate_anyOf(result_builder)
      # json-schema-validation 6.28.  oneOf
      internal_validate_oneOf(result_builder)
    end
  end
end

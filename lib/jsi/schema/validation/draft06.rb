# frozen_string_literal: true

module JSI
  module Schema::Validation::Draft06
    include Schema::Validation::Ref
    include Schema::Validation::AllOf
    include Schema::Validation::AnyOf
    include Schema::Validation::OneOf
    include Schema::Validation::Not

    include Schema::Validation::Items
    include Schema::Validation::Contains
    include Schema::Validation::Properties

    include Schema::Validation::MultipleOf
    include Schema::Validation::MinMax

    include Schema::Validation::StringLength

    include Schema::Validation::Pattern

    include Schema::Validation::ArrayLength
    include Schema::Validation::UniqueItems

    include Schema::Validation::MinMaxProperties
    include Schema::Validation::Required
    include Schema::Validation::Dependencies
    include Schema::Validation::PropertyNames

    include Schema::Validation::Const
    include Schema::Validation::Enum

    include Schema::Validation::Type

    # @private
    def internal_validate_keywords(result_builder)
      # json-schema 8.  Schema references with $ref
      internal_validate_ref(result_builder, throw_result: true)

      # json-schema-validation 6.1.  multipleOf
      internal_validate_multipleOf(result_builder)

      # json-schema-validation 6.2.  maximum
      internal_validate_maximum(result_builder)

      # json-schema-validation 6.3.  exclusiveMaximum
      internal_validate_exclusiveMaximum(result_builder)

      # json-schema-validation 6.4.  minimum
      internal_validate_minimum(result_builder)

      # json-schema-validation 6.5.  exclusiveMinimum
      internal_validate_exclusiveMinimum(result_builder)

      # json-schema-validation 6.6.  maxLength
      internal_validate_maxLength(result_builder)

      # json-schema-validation 6.7.  minLength
      internal_validate_minLength(result_builder)

      # json-schema-validation 6.8.  pattern
      internal_validate_pattern(result_builder)

      # json-schema-validation 6.9.  items
      # json-schema-validation 6.10.  additionalItems
      internal_validate_items(result_builder)

      # json-schema-validation 6.11.  maxItems
      internal_validate_maxItems(result_builder)

      # json-schema-validation 6.12.  minItems
      internal_validate_minItems(result_builder)

      # json-schema-validation 6.13.  uniqueItems
      internal_validate_uniqueItems(result_builder)

      # json-schema-validation 6.14.  contains
      internal_validate_contains(result_builder)

      # json-schema-validation 6.15.  maxProperties
      internal_validate_maxProperties(result_builder)

      # json-schema-validation 6.16.  minProperties
      internal_validate_minProperties(result_builder)

      # json-schema-validation 6.17.  required
      internal_validate_required(result_builder)

      # json-schema-validation 6.18.  properties
      # json-schema-validation 6.19.  patternProperties
      # json-schema-validation 6.20.  additionalProperties
      internal_validate_properties(result_builder)

      # json-schema-validation 6.21.  dependencies
      internal_validate_dependencies(result_builder)

      # json-schema-validation 6.22.  propertyNames
      internal_validate_propertyNames(result_builder)

      # json-schema-validation 6.23.  enum
      internal_validate_enum(result_builder)

      # json-schema-validation 6.24.  const
      internal_validate_const(result_builder)

      # json-schema-validation 6.25.  type
      internal_validate_type(result_builder)

      # json-schema-validation 6.26.  allOf
      internal_validate_allOf(result_builder)
      # json-schema-validation 6.27.  anyOf
      internal_validate_anyOf(result_builder)
      # json-schema-validation 6.28.  oneOf
      internal_validate_oneOf(result_builder)

      # json-schema-validation 6.29.  not
      internal_validate_not(result_builder)
    end
  end
end

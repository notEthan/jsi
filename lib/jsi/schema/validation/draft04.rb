# frozen_string_literal: true

module JSI
  module Schema::Validation::Draft04
    autoload(:MinMax, 'jsi/schema/elements/numeric_draft04')

    include Schema::Validation::Ref

    include Schema::Validation::MultipleOf
    include Schema::Validation::Draft04::MinMax

    include Schema::Validation::StringLength
    include Schema::Validation::Pattern

    include Schema::Validation::Items
    include Schema::Validation::ArrayLength
    include Schema::Validation::UniqueItems

    include Schema::Validation::MinMaxProperties
    include Schema::Validation::Required
    include Schema::Validation::Properties
    include Schema::Validation::Dependencies

    include Schema::Validation::Enum
    include Schema::Validation::Type

    include Schema::Validation::AllOf
    include Schema::Validation::AnyOf
    include Schema::Validation::OneOf
    include Schema::Validation::Not

    # @private
    def internal_validate_keywords(result_builder)
      internal_validate_ref(result_builder, throw_result: true)

      # 5.1.  Validation keywords for numeric instances (number and integer)

      # 5.1.1.  multipleOf
      internal_validate_multipleOf(result_builder)

      # 5.1.2.  maximum and exclusiveMaximum
      internal_validate_maximum(result_builder)

      # 5.1.3.  minimum and exclusiveMinimum
      internal_validate_minimum(result_builder)

      # 5.2.  Validation keywords for strings

      # 5.2.1.  maxLength
      internal_validate_maxLength(result_builder)

      # 5.2.2.  minLength
      internal_validate_minLength(result_builder)

      # 5.2.3.  pattern
      internal_validate_pattern(result_builder)

      # 5.3.  Validation keywords for arrays

      # 5.3.1.  additionalItems and items
      internal_validate_items(result_builder)

      # 5.3.2.  maxItems
      internal_validate_maxItems(result_builder)

      # 5.3.3.  minItems
      internal_validate_minItems(result_builder)

      # 5.3.4.  uniqueItems
      internal_validate_uniqueItems(result_builder)

      # 5.4.  Validation keywords for objects

      # 5.4.1.  maxProperties
      internal_validate_maxProperties(result_builder)

      # 5.4.2.  minProperties
      internal_validate_minProperties(result_builder)

      # 5.4.3.  required
      internal_validate_required(result_builder)

      # 5.4.4.  additionalProperties, properties and patternProperties
      internal_validate_properties(result_builder)

      # 5.4.5.  dependencies
      internal_validate_dependencies(result_builder)

      # 5.5.  Validation keywords for any instance type

      # 5.5.1.  enum
      internal_validate_enum(result_builder)

      # 5.5.2.  type
      internal_validate_type(result_builder)

      # 5.5.3.  allOf
      internal_validate_allOf(result_builder)

      # 5.5.4.  anyOf
      internal_validate_anyOf(result_builder)

      # 5.5.5.  oneOf
      internal_validate_oneOf(result_builder)

      # 5.5.6.  not
      internal_validate_not(result_builder)
    end
  end
end

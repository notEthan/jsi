# frozen_string_literal: true

module JSI
  module Schema::Validation::Draft07
    include Schema::Validation::Ref

    include Schema::Validation::Type
    include Schema::Validation::Enum
    include Schema::Validation::Const

    include Schema::Validation::MultipleOf
    include Schema::Validation::MinMax

    include Schema::Validation::StringLength
    include Schema::Validation::Pattern

    include Schema::Validation::Items
    include Schema::Validation::ArrayLength
    include Schema::Validation::UniqueItems
    include Schema::Validation::Contains

    include Schema::Validation::MinMaxProperties
    include Schema::Validation::Required

    include Schema::Validation::Properties
    include Schema::Validation::Dependencies
    include Schema::Validation::PropertyNames

    include Schema::Validation::IfThenElse
    include Schema::Validation::AllOf
    include Schema::Validation::AnyOf
    include Schema::Validation::OneOf
    include Schema::Validation::Not

    # @private
    def internal_validate_keywords(result_builder)
      internal_validate_ref(result_builder, throw_result: true)

      # 6.1.  Validation Keywords for Any Instance Type

      # 6.1.1.  type
      internal_validate_type(result_builder)

      # 6.1.2.  enum
      internal_validate_enum(result_builder)

      # 6.1.3.  const
      internal_validate_const(result_builder)

      # 6.2.  Validation Keywords for Numeric Instances (number and integer)

      # 6.2.1.  multipleOf
      internal_validate_multipleOf(result_builder)

      # 6.2.2.  maximum
      internal_validate_maximum(result_builder)

      # 6.2.3.  exclusiveMaximum
      internal_validate_exclusiveMaximum(result_builder)

      # 6.2.4.  minimum
      internal_validate_minimum(result_builder)

      # 6.2.5.  exclusiveMinimum
      internal_validate_exclusiveMinimum(result_builder)

      # 6.3.  Validation Keywords for Strings

      # 6.3.1.  maxLength
      internal_validate_maxLength(result_builder)

      # 6.3.2.  minLength
      internal_validate_minLength(result_builder)

      # 6.3.3.  pattern
      internal_validate_pattern(result_builder)

      # 6.4.  Validation Keywords for Arrays

      # 6.4.1.  items
      # 6.4.2.  additionalItems
      internal_validate_items(result_builder)

      # 6.4.3.  maxItems
      internal_validate_maxItems(result_builder)

      # 6.4.4.  minItems
      internal_validate_minItems(result_builder)

      # 6.4.5.  uniqueItems
      internal_validate_uniqueItems(result_builder)

      # 6.4.6.  contains
      internal_validate_contains(result_builder)

      # 6.5.  Validation Keywords for Objects

      # 6.5.1.  maxProperties
      internal_validate_maxProperties(result_builder)

      # 6.5.2.  minProperties
      internal_validate_minProperties(result_builder)

      # 6.5.3.  required
      internal_validate_required(result_builder)

      # 6.5.4.  properties
      # 6.5.5.  patternProperties
      # 6.5.6.  additionalProperties
      internal_validate_properties(result_builder)

      # 6.5.7.  dependencies
      internal_validate_dependencies(result_builder)

      # 6.5.8.  propertyNames
      internal_validate_propertyNames(result_builder)

      # 6.6.  Keywords for Applying Subschemas Conditionally

      # 6.6.1.  if
      # 6.6.2.  then
      # 6.6.3.  else
      internal_validate_ifthenelse(result_builder)

      # 6.7.  Keywords for Applying Subschemas With Boolean Logic

      # 6.7.1.  allOf
      internal_validate_allOf(result_builder)

      # 6.7.2.  anyOf
      internal_validate_anyOf(result_builder)

      # 6.7.3.  oneOf
      internal_validate_oneOf(result_builder)

      # 6.7.4.  not
      internal_validate_not(result_builder)

      # 7.  Semantic Validation With "format"
      # TODO

      # 10.  Schema Annotations

      # 10.1.  "title" and "description"
      # TODO

      # 10.2.  "default"
      # TODO

      # 10.3.  "readOnly" and "writeOnly"
      # TODO

      # 10.4.  "examples"
      # TODO
    end
  end
end

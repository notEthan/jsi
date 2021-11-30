# frozen_string_literal: true

module JSI
  module Schema::Validation::Draft07
    include Schema::Validation::Ref

    include Schema::Validation::Items
    include Schema::Validation::Contains

    include Schema::Validation::Properties
    include Schema::Validation::Dependencies
    include Schema::Validation::IfThenElse
    include Schema::Validation::AllOf
    include Schema::Validation::AnyOf
    include Schema::Validation::OneOf

    # @private
    def internal_validate_keywords(result_builder)
      internal_validate_ref(result_builder, throw_result: true)

      # 6.4.  Validation Keywords for Arrays

      # 6.4.1.  items
      # 6.4.2.  additionalItems
      internal_validate_items(result_builder)

      # 6.4.6.  contains
      internal_validate_contains(result_builder)

      # 6.5.  Validation Keywords for Objects

      # 6.5.4.  properties
      # 6.5.5.  patternProperties
      # 6.5.6.  additionalProperties
      internal_validate_properties(result_builder)

      # 6.5.7.  dependencies
      internal_validate_dependencies(result_builder)

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
    end
  end
end

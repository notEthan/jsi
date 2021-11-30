# frozen_string_literal: true

module JSI
  module Schema::Validation::Draft04
    include Schema::Validation::Ref

    include Schema::Validation::Items

    include Schema::Validation::Properties
    include Schema::Validation::Dependencies

    include Schema::Validation::AllOf
    include Schema::Validation::AnyOf
    include Schema::Validation::OneOf

    # @private
    def internal_validate_keywords(result_builder)
      internal_validate_ref(result_builder, throw_result: true)

      # 5.3.  Validation keywords for arrays

      # 5.3.1.  additionalItems and items
      internal_validate_items(result_builder)

      # 5.4.  Validation keywords for objects

      # 5.4.4.  additionalProperties, properties and patternProperties
      internal_validate_properties(result_builder)

      # 5.4.5.  dependencies
      internal_validate_dependencies(result_builder)

      # 5.5.  Validation keywords for any instance type

      # 5.5.3.  allOf
      internal_validate_allOf(result_builder)

      # 5.5.4.  anyOf
      internal_validate_anyOf(result_builder)

      # 5.5.5.  oneOf
      internal_validate_oneOf(result_builder)
    end
  end
end

# frozen_string_literal: true

module JSI
  module Schema::Validation::Draft07
    include Schema::Validation::Core

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
  end
end

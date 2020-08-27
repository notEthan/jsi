# frozen_string_literal: true

module JSI
  module Schema::Validation::Draft04
    autoload :MinMax, 'jsi/schema/validation/draft04/minmax'

    include Schema::Validation::Core

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
  end
end

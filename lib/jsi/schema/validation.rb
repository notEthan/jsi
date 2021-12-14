# frozen_string_literal: true

module JSI
  module Schema::Validation
    autoload :Draft04, 'jsi/schema/validation/draft04'
    autoload :Draft06, 'jsi/schema/validation/draft06'
    autoload :Draft07, 'jsi/schema/validation/draft07'

    # ref application
    autoload :Ref, 'jsi/schema/validation/ref'

    # inplace subschema application
    autoload :AllOf, 'jsi/schema/validation/someof'
    autoload :AnyOf, 'jsi/schema/validation/someof'
    autoload :OneOf, 'jsi/schema/validation/someof'
    autoload :IfThenElse, 'jsi/schema/validation/ifthenelse'

    # child subschema application
    autoload :Items,    'jsi/schema/validation/items'
    autoload :Contains,  'jsi/schema/validation/contains'
    autoload :Properties, 'jsi/schema/validation/properties'

    # property names subschema application
    autoload(:PropertyNames, 'jsi/schema/elements/property_names')

    # any type validation
    autoload(:Type, 'jsi/schema/elements/type')
    autoload(:Enum, 'jsi/schema/elements/enum')
    autoload(:Const, 'jsi/schema/elements/const')
    autoload(:Not,  'jsi/schema/elements/not')

    # object validation
    autoload(:Required,    'jsi/schema/elements/required')
    autoload :Dependencies, 'jsi/schema/validation/dependencies'
    autoload(:MinMaxProperties, 'jsi/schema/elements/object_validation')

    # array validation
    autoload(:ArrayLength, 'jsi/schema/elements/array_validation')
    autoload(:UniqueItems, 'jsi/schema/elements/array_validation')

    # string validation
    autoload(:StringLength, 'jsi/schema/elements/string_validation')
    autoload(:Pattern, 'jsi/schema/elements/pattern')

    # numeric validation
    autoload(:MultipleOf, 'jsi/schema/elements/numeric')
    autoload(:MinMax,    'jsi/schema/elements/numeric')
  end
end

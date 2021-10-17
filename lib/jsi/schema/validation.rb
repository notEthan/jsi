# frozen_string_literal: true

module JSI
  module Schema::Validation
    autoload :Core, 'jsi/schema/validation/core'

    autoload :Draft04, 'jsi/schema/validation/draft04'
    autoload :Draft06, 'jsi/schema/validation/draft06'
    autoload :Draft07, 'jsi/schema/validation/draft07'

    # ref application
    autoload :Ref, 'jsi/schema/validation/ref'

    # inplace subschema application
    autoload :AllOf, 'jsi/schema/validation/someof'
    autoload :AnyOf, 'jsi/schema/validation/someof'
    autoload :OneOf, 'jsi/schema/validation/someof'
    autoload :Not,  'jsi/schema/validation/not'
    autoload :IfThenElse, 'jsi/schema/validation/ifthenelse'

    # child subschema application
    autoload :Items,    'jsi/schema/validation/items'
    autoload :Contains,  'jsi/schema/validation/contains'
    autoload :Properties, 'jsi/schema/validation/properties'

    # property names subschema application
    autoload :PropertyNames, 'jsi/schema/validation/property_names'

    # any type validation
    autoload :Type, 'jsi/schema/validation/type'
    autoload :Enum, 'jsi/schema/validation/enum'
    autoload :Const, 'jsi/schema/validation/const'

    # object validation
    autoload :Required,    'jsi/schema/validation/required'
    autoload :Dependencies, 'jsi/schema/validation/dependencies'
    autoload :MinMaxProperties, 'jsi/schema/validation/object'

    # array validation
    autoload :ArrayLength, 'jsi/schema/validation/array'
    autoload :UniqueItems, 'jsi/schema/validation/array'

    # string validation
    autoload :StringLength, 'jsi/schema/validation/string'
    autoload :Pattern, 'jsi/schema/validation/pattern'

    # numeric validation
    autoload :MultipleOf, 'jsi/schema/validation/numeric'
    autoload :MinMax,    'jsi/schema/validation/numeric'
  end
end

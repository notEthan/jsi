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

    # object validation
    autoload :Dependencies, 'jsi/schema/validation/dependencies'
  end
end

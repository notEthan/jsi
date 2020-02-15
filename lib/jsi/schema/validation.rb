# frozen_string_literal: true

module JSI
  module Schema::Validation
    autoload :Core, 'jsi/schema/validation/core'

    # ref application
    autoload :Ref, 'jsi/schema/validation/ref'

    # inplace subschema application
    autoload :AllOf, 'jsi/schema/validation/someof'
    autoload :AnyOf, 'jsi/schema/validation/someof'
    autoload :OneOf, 'jsi/schema/validation/someof'

    # child subschema application

    # property names subschema application

    # any type validation

    # object validation

    # array validation

    # string validation

    # numeric validation
  end
end

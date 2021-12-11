# frozen_string_literal: true

module JSI
  module Schema::Application::InplaceApplication
    autoload :Draft04, 'jsi/schema/application/inplace_application/draft04'
    autoload :Draft06, 'jsi/schema/application/inplace_application/draft06'
    autoload :Draft07, 'jsi/schema/application/inplace_application/draft07'

    autoload(:SomeOf, 'jsi/schema/elements/some_of')
    autoload(:IfThenElse, 'jsi/schema/elements/if_then_else')
    autoload(:Dependencies, 'jsi/schema/elements/dependencies')
  end
end

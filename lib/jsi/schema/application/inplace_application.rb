# frozen_string_literal: true

module JSI
  module Schema::Application::InplaceApplication
    autoload :Draft04, 'jsi/schema/application/inplace_application/draft04'
    autoload :Draft06, 'jsi/schema/application/inplace_application/draft06'
    autoload :Draft07, 'jsi/schema/application/inplace_application/draft07'

    autoload :Ref, 'jsi/schema/application/inplace_application/ref'
    autoload :SomeOf, 'jsi/schema/application/inplace_application/someof'
    autoload :IfThenElse, 'jsi/schema/application/inplace_application/ifthenelse'
    autoload :Dependencies, 'jsi/schema/application/inplace_application/dependencies'
  end
end

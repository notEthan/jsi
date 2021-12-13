# frozen_string_literal: true

module JSI
  module Schema::Application::ChildApplication
    autoload :Draft04, 'jsi/schema/application/child_application/draft04'
    autoload :Draft06, 'jsi/schema/application/child_application/draft06'
    autoload :Draft07, 'jsi/schema/application/child_application/draft07'

    autoload(:Items, 'jsi/schema/elements/items')
    autoload(:Contains, 'jsi/schema/elements/contains')
    autoload(:Properties, 'jsi/schema/elements/properties')
  end
end

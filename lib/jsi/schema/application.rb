# frozen_string_literal: true

module JSI
  module Schema::Application
    autoload :InplaceApplication, 'jsi/schema/application/inplace_application'
    autoload :ChildApplication, 'jsi/schema/application/child_application'

    autoload :Draft04, 'jsi/schema/application/draft04'
    autoload :Draft06, 'jsi/schema/application/draft06'
    autoload :Draft07, 'jsi/schema/application/draft07'
  end
end

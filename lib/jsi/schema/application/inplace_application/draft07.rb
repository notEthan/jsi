# frozen_string_literal: true

module JSI
  module Schema::Application::InplaceApplication::Draft07
    include Schema::Application::InplaceApplication
    include Schema::Application::InplaceApplication::Ref
    include Schema::Application::InplaceApplication::Dependencies
    include Schema::Application::InplaceApplication::IfThenElse
    include Schema::Application::InplaceApplication::SomeOf
  end
end

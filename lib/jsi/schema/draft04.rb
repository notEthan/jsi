# frozen_string_literal: true

module JSI
  module Schema
    module Draft04
      include Schema
      include Schema::Application::InplaceApplication
      include Schema::Application::ChildApplication
    end
  end
end

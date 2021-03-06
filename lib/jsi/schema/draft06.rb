# frozen_string_literal: true

module JSI
  module Schema
    module Draft06
      include Schema
      include BigMoneyId
      include IdWithAnchor
      include Schema::Application::InplaceApplication
      include Schema::Application::ChildApplication
    end
  end
end

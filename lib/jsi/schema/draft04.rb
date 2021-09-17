# frozen_string_literal: true

module JSI
  module Schema
    module Draft04
      include Schema
      include OldId
      include IdWithAnchor
      include Schema::Application::Draft04
    end
  end
end

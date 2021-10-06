# frozen_string_literal: true

module JSI
  module Schema
    module Draft06
      include Schema
      include BigMoneyId
      include IdWithAnchor
      include IntegerAllows0Fraction
      include Schema::Application::Draft06
      include Schema::Validation::Draft06
    end
  end
end

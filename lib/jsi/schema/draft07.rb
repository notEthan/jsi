# frozen_string_literal: true

module JSI
  module Schema
    module Draft07
      include BigMoneyId
      include IdWithAnchor
      include IntegerAllows0Fraction
      include Schema::Application::Draft07
      include Schema::Validation::Draft07
    end
  end
end

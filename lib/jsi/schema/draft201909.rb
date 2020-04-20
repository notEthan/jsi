# frozen_string_literal: true

module JSI
  module Schema
    module Draft201909
      include JSI::Schema

      include BigMoneyId
      include BigMoneyAnchor
      include BigMoneyDefs
    end
  end
end

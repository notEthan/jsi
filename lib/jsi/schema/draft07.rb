# frozen_string_literal: true

module JSI
  module Schema
    module Draft07
      include JSI::Schema

      include BigMoneyId
      include Definitions
    end
  end
end

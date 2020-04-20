# frozen_string_literal: true

module JSI
  module Schema
    module Draft06
      include JSI::Schema

      include BigMoneyId
      include Definitions
    end
  end
end

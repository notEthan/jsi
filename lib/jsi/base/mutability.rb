# frozen_string_literal: true

module JSI
  module Base::Mutable
    def jsi_mutable?
      true
    end
  end

  module Base::Immutable
    def jsi_mutable?
      false
    end
  end
end

# frozen_string_literal: true

module JSI
  module Base::Mutable
    def jsi_mutable?
      true
    end

    private

    def jsi_mutability_initialize
    end
  end

  module Base::Immutable
    def jsi_mutable?
      false
    end

    private

    def jsi_mutability_initialize
    end
  end
end

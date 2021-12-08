# frozen_string_literal: true

module JSI
  class Schema::Cxt
    ChildApplication = Block.subclass(*%w(
      instance
      token
    ))

    class ChildApplication
    end
  end
end

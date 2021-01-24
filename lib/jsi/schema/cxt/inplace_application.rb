# frozen_string_literal: true

module JSI
  class Schema::Cxt
    InplaceApplication = Block.subclass(*%w(
      instance
      visited_refs
    ))

    class InplaceApplication
    end
  end
end

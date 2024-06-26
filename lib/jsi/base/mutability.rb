# frozen_string_literal: true

module JSI
  module Base::Mutable
    include(Util::FingerprintHash)

    def jsi_node_content
      jsi_ptr.evaluate(jsi_document)
    end

    def jsi_mutable?
      true
    end

    private

    def jsi_mutability_initialize
    end

    def jsi_memomap_class
      Util::MemoMap::Mutable
    end
  end

  module Base::Immutable
    include(Util::FingerprintHash::Immutable)

    attr_reader(:jsi_node_content)

    def jsi_mutable?
      false
    end

    private

    def jsi_mutability_initialize
      @jsi_node_content = @jsi_ptr.evaluate(@jsi_document)
    end

    def jsi_memomap_class
      Util::MemoMap::Immutable
    end
  end
end

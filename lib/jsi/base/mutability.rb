# frozen_string_literal: true

module JSI
  module Base::Mutable
    def jsi_node_content
      jsi_ptr.evaluate(jsi_document)
    end

    def jsi_mutable?
      true
    end

    private

    def jsi_mutability_initialize
    end
  end

  module Base::Immutable
    attr_reader(:jsi_node_content)

    def jsi_mutable?
      false
    end

    private

    def jsi_mutability_initialize
      @jsi_node_content = @jsi_ptr.evaluate(@jsi_document)
    end
  end
end

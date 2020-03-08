# frozen_string_literal: true

module JSI
  class BasicSchema
    include Util::Memoize
    include Util::FingerprintHash

    # @param ptr [JSI::JSON::Pointer] pointer to the schema in the document
    # @param document [#to_hash, #to_ary, Boolean, Object] document containing the schema
    def initialize(ptr, document)
      unless ptr.is_a?(JSI::JSON::Pointer)
        raise(TypeError, "ptr is not a JSI::JSON::Pointer: #{ptr.inspect}")
      end
      @ptr = ptr
      @document = document

      @schema_content = ptr.evaluate(document)
    end

    # document containing the schema content
    attr_reader :document

    # JSI::JSON::Pointer pointing to this schema within the document
    attr_reader :ptr

    # underlying schema content (boolean or ruby Hash / json object)
    attr_reader :schema_content

    # @private
    def jsi_fingerprint
      {class: self.class, ptr: @ptr, document: @document}
    end
  end
end

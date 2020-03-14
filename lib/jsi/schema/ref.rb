# frozen_string_literal: true

module JSI
  # JSI::Schema::Ref is a reference to another schema (the result of #deref_schema), resolved using a ref URI
  # from a ref schema (the ref URI typically the contents of the ref_schema's "$ref" keyword)
  class Schema::Ref
    # @param ref [String] a reference URI
    # @param ref_schema [JSI::Schema] a schema from which the reference originated
    def initialize(ref, ref_schema)
      raise(ArgumentError, "ref is not a string") unless ref.respond_to?(:to_str)
      @ref = ref
      @ref_uri = Addressable::URI.parse(ref)
      @ref_schema = ref_schema
    end

    attr_reader :ref

    attr_reader :ref_uri

    attr_reader :ref_schema

    # @private
    def jsi_fingerprint
      {class: self.class, ref: ref, ref_schema: ref_schema}
    end
    include Util::FingerprintHash
  end
end

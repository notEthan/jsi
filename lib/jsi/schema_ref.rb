module JSI
  class SchemaRef
    def initialize(schema, keyword)
      @schema = schema
      @keyword = keyword

      @ref = schema.schema_content[keyword]
      @ref_uri = Addressable::URI.parse(ref)
    end

    attr_reader :schema
    attr_reader :keyword

    attr_reader :ref
    attr_reader :ref_uri

    def deref_schema
      return @deref_schema if instance_variable_defined?(:@deref_schema)

      if ref_uri == Addressable::URI.new(fragment: ref_uri.fragment)
        return(@deref_schema = schema.schema_from_resource_root(JSI::JSON::Pointer.from_fragment(ref_uri.fragment)))
      else
        return(@deref_schema = JSI.schema_registry.find_schema(self))
      end
    end

    def jsi_fingerprint
      {class: self.class, schema: schema, keyword: keyword}
    end
    include Util::FingerprintHash
  end
end

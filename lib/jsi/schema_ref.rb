module JSI
  class SchemaRef
    def initialize(schema, keyword)
      @schema = schema
      @keyword = keyword

      @ref = schema.schema_content[keyword]

      if schema.base_uri
        @ref_uri = schema.base_uri.join(ref)
      else
        @ref_uri = Addressable::URI.parse(ref)
      end

      if ref[/\A#/]
        @deref_schema = schema.rename_this_subschema_from_root(JSI::JSON::Pointer.from_fragment(ref_uri.fragment))
      end
    end

    attr_reader :schema
    attr_reader :keyword

    attr_reader :ref
    attr_reader :ref_uri

    def deref_schema
      return @deref_schema if instance_variable_defined?(:@deref_schema)
      return(@deref_schema = JSI.schema_registry.find_schema(self))
    end

    def jsi_fingerprint
      {class: self.class, schema: schema, keyword: keyword}
    end
    include Util::FingerprintHash
  end
end

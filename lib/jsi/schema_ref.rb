module JSI
  class SchemaRef
    def initialize(basic_schema, keyword)
      @basic_schema = basic_schema
      @keyword = keyword

      @ref = basic_schema.schema_content[keyword]
      @ref_uri = Addressable::URI.parse(ref)

      if ref[/\A#/]
        @deref_basic_schema = basic_schema / JSI::JSON::Pointer.from_fragment(ref_uri.fragment)
      end
    end

    attr_reader :basic_schema
    attr_reader :keyword

    attr_reader :ref
    attr_reader :ref_uri

    def deref_basic_schema
      return @deref_basic_schema if instance_variable_defined?(:@deref_basic_schema)
    end

    def jsi_fingerprint
      {class: self.class, basic_schema: basic_schema, keyword: keyword}
    end
    include Util::FingerprintHash
  end
end

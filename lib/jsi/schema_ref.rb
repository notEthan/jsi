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
        fragment = ref_uri.fragment
        schema_resource_root = schema.jsi_subschema_resource_ancestors.last || schema.jsi_root_node

        if schema_resource_root.is_a?(JSI::Schema)
          return(@deref_schema = schema_resource_root.subschema_from_fragment(fragment))
        else
          begin
            ptr = JSI::JSON::Pointer.from_fragment(fragment)
            result_schema = ptr.evaluate(schema_resource_root)
            if result_schema.is_a?(JSI::Schema)
              return(@deref_schema = result_schema)              
            else
              raise(Schema::ReferenceError, "object identified by uri #{ref_uri.to_s} is not a schema:\n#{result_schema.pretty_inspect.chomp}")
            end
          rescue JSI::JSON::Pointer::PointerSyntaxError
            raise(Schema::ReferenceError, "could not find schema from uri #{ref_uri.to_s} in document:\n#{schema_resource_root.pretty_inspect.chomp}")
          end
        end
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

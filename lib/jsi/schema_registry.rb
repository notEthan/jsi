module JSI
  class SchemaRegistry
    class Error < StandardError
    end
    class Collision < Error
    end
    class RelativeURIRegistration < Error
    end
    class SchemaNotFound < Error
    end

    def initialize
      @schemas = {}
      @schema_documents = {}
    end

    attr_reader :schemas

    attr_reader :schema_documents

    def register_document(id, schema_document)
      id = Addressable::URI.parse(id)
      if id.relative?
        raise(RelativeURIRegistration, "cannot register relative id URI #{id}. would you kindly pass an absolute URI in the `id` param?")
      else
        if id.fragment == ''
          id.fragment = nil
        elsif id.fragment
          raise(Schema::IdHasFragment.new("schema id must not have a fragment. id: #{id}\nNOTE: a fragment is technically allowed in older JSON schema specifications. this is currently not supported, but support could be added. if you require this, please open an issue at https://github.com/notEthan/jsi/issues").tap { |e| e.id = id })
        end
        if @schema_documents.key?(id)
          if @schema_documents[id] != schema_document
            raise(Collision, "id collision on #{id}. existing: \n#{@schema_documents[id].pretty_inspect.chomp}\nnew:\n#{schema_documents.pretty_inspect.chomp}")
          end
        else
          @schema_documents[id] = schema_document
        end
      end
    end

    def register(schema, schema_id: nil)
      #unless schema.is_a?(JSI::Schema)
      #  raise(TypeError, "schema must be a JSI::Schema; got: #{schema.pretty_inspect}")
      #end

      if schema_id && !(schema.is_a?(Schema) && schema.id)
        register_single(schema, Addressable::URI.parse(schema_id))
      end

      JSI::Util.ycomb do |rec|
        proc do |node, base_id|
          if node.is_a?(JSI::Schema)
            [node].each do |schema_node|
              schema_node_id = schema_node.id
              if schema_node_id
                base_id = base_id ? base_id.join(schema_node_id) : Addressable::URI.parse(schema_node_id)

                register_single(node, base_id)
              end
              if schema_node.respond_to?(:to_hash)
                schema_node.to_hash.values.each { |v| rec.call(v, base_id) }
              elsif schema_node.respond_to?(:to_ary)
                schema_node.to_ary.each { |e| rec.call(e, base_id) }
              end
            end
          elsif node.respond_to?(:to_hash)
            node.to_hash.values.each { |v| rec.call(v, base_id) }
          elsif node.respond_to?(:to_ary)
            node.to_ary.each { |e| rec.call(e, base_id) }
          end
        end
      end.call(schema, schema_id ? Addressable::URI.parse(schema_id) : nil)
    end

    def find_schema(schema_ref)
#byebug if schema_ref.ref_uri.relative?
      if schema_ref.ref_uri.fragment
        # TODO error handling fragment with invalid pointer
        ptr = JSI::JSON::Pointer.from_fragment(schema_ref.ref_uri.fragment)
      else
        ptr = JSI::JSON::Pointer[]
      end
      ref_root_uri = schema_ref.ref_uri.merge(fragment: nil)

      if @schemas.key?(ref_root_uri)
        ptr.evaluate(@schemas[ref_root_uri]).tap do |schema|
          unless schema.is_a?(JSI::Schema)
byebug
ptr.evaluate(@schemas[ref_root_uri])
            raise(JSI::Schema::NotASchemaError, "referenced schema is not a schema with id: #{id}: #{schema.pretty_inspect.chomp}")
          end
        end
      else
byebug
        raise(SchemaNotFound, "id #{ref_root_uri} not in ids:\n#{@schemas.keys.join("\n")}")
      end
    end

    def find_basic_schema(schema_ref)
#byebug if schema_ref.ref_uri.relative?
      if schema_ref.ref_uri.fragment
        # TODO error handling fragment with invalid pointer
        ptr = JSI::JSON::Pointer.from_fragment(schema_ref.ref_uri.fragment)
      else
        ptr = JSI::JSON::Pointer[]
      end
      ref_root_uri = schema_ref.ref_uri.merge(fragment: nil)

      if @schema_documents.key?(ref_root_uri)
        schema_ref.basic_schema.class.new(ptr, @schema_documents[ref_root_uri])
#      elsif @schemas.key?(ref_root_uri)
      else
        find_schema(schema_ref).jsi_instance_basic_schema

#byebug
#        raise(SchemaNotFound, "id #{ref_root_uri} not in ids:\n#{(@schema_documents.keys | @schemas.keys).join("\n")}")
      end
    end

    private
    def register_single(schema, id)
      if id.relative?
        raise(RelativeURIRegistration, "cannot register relative id URI #{id}. would you kindly pass an absolute URI in the `id` param?")
      else
        if id.fragment == ''
          id.fragment = nil
        elsif id.fragment
          raise(Schema::IdHasFragment.new("schema id must not have a fragment. id: #{id}\nNOTE: a fragment is technically allowed in older JSON schema specifications. this is currently not supported, but support could be added. if you require this, please open an issue at https://github.com/notEthan/jsi/issues").tap { |e| e.id = id })
        end
        if @schemas.key?(id)
          if @schemas[id] != schema
            raise(Collision, "id collision on #{id}. existing: \n#{@schemas[id].pretty_inspect.chomp}\nnew:\n#{schema.pretty_inspect.chomp}")
          end
        else
          @schemas[id] = schema
        end
      end
    end
  end
end

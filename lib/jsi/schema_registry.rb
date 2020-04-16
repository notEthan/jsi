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
      @schemas_mutex = Mutex.new
    end

    attr_reader :schemas

    def register(schema, schema_id: nil)
      if schema_id && !(schema.is_a?(Schema) && schema.id)
        register_single(schema, Addressable::URI.parse(schema_id))
      end

      JSI::Util.ycomb do |rec|
        proc do |node, base_id|
          if node.is_a?(JSI::Schema)
            schema_node = node
            if schema_node.id
              base_id = base_id ? base_id.join(schema_node.id) : Addressable::URI.parse(schema_node.id)

              register_single(node, base_id)
            end
            if schema_node.respond_to?(:to_hash)
              schema_node.to_hash.values.each { |v| rec.call(v, base_id) }
            elsif schema_node.respond_to?(:to_ary)
              schema_node.to_ary.each { |e| rec.call(e, base_id) }
            end
          elsif node.respond_to?(:to_hash)
            node.to_hash.values.each { |v| rec.call(v, base_id) }
          elsif node.respond_to?(:to_ary)
            node.to_ary.each { |e| rec.call(e, base_id) }
          end
        end
      end.call(schema, schema_id ? Addressable::URI.parse(schema_id) : nil)
      nil
    end

    def find_schema(schema_ref)
      if schema_ref.schema.base_uri
        schema_uri = schema_ref.schema.base_uri.join(schema_ref.ref)
      else
        schema_uri = Addressable::URI.parse(schema_ref.ref)
      end
byebug if schema_uri.relative?

      fragment = schema_uri.fragment
      schema_uri = schema_uri.merge(fragment: nil)

      if @schemas.key?(schema_uri)
        schema = @schemas[schema_uri]
        if fragment
          schema.subschema_from_fragment(fragment)
        else
          schema
        end
      else
byebug
        raise(SchemaNotFound, "id #{schema_uri} not in ids:\n#{@schemas.keys.join("\n")}")
      end
    end

    private
    # @return [void]
    def register_single(schema, id)
      if id.relative?
        raise(RelativeURIRegistration, "cannot register relative id URI #{id}. would you kindly pass an absolute URI in the `id` param?")
      else
        if id.fragment == ''
          id = id.merge(fragment: nil)
        elsif id.fragment
byebug

          raise(Schema::UndefinedIdFragment.new("schema id must not have a fragment. id: #{id}\nNOTE: a fragment is technically allowed in older JSON schema specifications. this is currently not supported, but support could be added. if you require this, please open an issue at https://github.com/notEthan/jsi/issues").tap { |e| e.id = id })
        end
        @schemas_mutex.synchronize do
          if @schemas.key?(id)
            if @schemas[id] != schema
              raise(Collision, "id collision on #{id}.\nexisting: \n#{@schemas[id].pretty_inspect.chomp}\nnew:\n#{schema.pretty_inspect.chomp}")
            end
          else
            @schemas[id] = schema
          end
        end
      end
      nil
    end
  end
end

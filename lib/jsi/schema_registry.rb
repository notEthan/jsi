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
    end

    attr_reader :schemas

    def ids
      @schemas.keys
    end

    def register(schema, base_uri: nil)
      unless schema.is_a?(JSI::Schema)
        raise(TypeError, "schema must be a JSI::Schema; got: #{schema.pretty_inspect}")
      end

      JSI::Util.ycomb do |rec|
        proc do |node, base_uri|
          if node.is_a?(JSI::Schema)
            node.jsi_schema_nodes.each do |schema_node|
              id = schema_node.id
              if id
                id_uri = base_uri ? base_uri.join(id) : Addressable::URI.parse(id)

                if id_uri.relative?
                  raise(RelativeURIRegistration, "cannot register relative id URI #{id}; would you kindly pass the param `base_uri`")
                else
                  if id_uri.fragment == ''
                    id_uri.fragment = nil
                    id = id_uri.to_s
                  elsif id_uri.fragment
                    raise(Schema::IdHasFragment.new("schema id must not have a fragment. id: #{id}\nNOTE: a fragment is technically allowed in older JSON schema specifications. this is currently not supported, but support could be added. if you require this, please open an issue at https://github.com/notEthan/jsi/issues").tap { |e| e.id = id })
                  end
                  if @schemas.key?(id_uri)
                    if @schemas[id_uri] != schema
                      raise(Collision, "id collision on #{id}. existing: \n#{@schemas[id_uri].pretty_inspect.chomp}\nnew:\n#{schema.pretty_inspect.chomp}")
                    end
                  else
                    @schemas[id_uri] = schema
                  end
                end
                base_uri = id_uri
              end
              if schema_node.respond_to?(:to_hash)
                schema_node.to_hash.values.each { |v| rec.call(v, base_uri) }
              elsif schema_node.respond_to?(:to_ary)
                schema_node.to_ary.each { |e| rec.call(e, base_uri) }
              end
            end
          elsif node.respond_to?(:to_hash)
            node.to_hash.values.each { |v| rec.call(v, base_uri) }
          elsif node.respond_to?(:to_ary)
            node.to_ary.each { |e| rec.call(e, base_uri) }
          end
        end
      end.call(schema, base_uri ? Addressable::URI.parse(base_uri) : nil)


    end

    def find(id)
      id_uri = Addressable::URI.parse(id)
      if id_uri.fragment
# TODO error handling fragment with invalid pointer
        ptr = JSI::JSON::Pointer.from_fragment('#' + id_uri.fragment)
        id_uri.fragment = nil
      else
        ptr = JSI::JSON::Pointer[]
      end

      if @schemas.key?(id_uri)
        ptr.evaluate(@schemas[id_uri])
      else
        raise(SchemaNotFound, "id #{id} not in JSI.registered_schemas.ids:\n#{JSI.registered_schemas.ids.join("\n")}")
      end
    end
  end
end

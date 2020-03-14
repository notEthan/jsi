module JSI
  class SchemaRegistry
    class Error < StandardError
    end
    class Collision < Error
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

    def register(schema)
      unless schema.is_a?(JSI::Schema)
        raise(TypeError, "schema must be a JSI::Schema; got: #{schema.pretty_inspect}")
      end
      content = schema.jsi_node_content
      if content.respond_to?(:to_hash)
        content = content.to_hash
        if content.key?('$id') && content['$id'].respond_to?(:to_str)
          keyword = '$id'
          id = content['$id'].to_str
        elsif content.key?('id') && content['id'].respond_to?(:to_str)
          keyword = 'id'
          id = content['id'].to_str
        end
      end
      if id
        auri = Addressable::URI.parse(id)

        if auri.fragment == ''
          auri.fragment = nil
          id = auri.to_s
        elsif auri.fragment
          raise(Schema::IdHasFragment.new("schema #{keyword} has fragment. id: #{id}\nNOTE: a fragment is technically allowed in older JSON schema specifications. this is currently not supported, but support could be added. if you require this, please open an issue at https://github.com/notEthan/jsi/issues").tap { |e| e.id = id })
        end
        if @schemas.key?(auri)
          if @schemas[auri] != schema
            raise(Collision, "id collision on #{id}. existing: \n#{@schemas[auri].pretty_inspect.chomp}\nnew:\n#{schema.pretty_inspect.chomp}")
          end
        else
          @schemas[auri] = schema
        end
      end
    end

    def find(id)
      auri = Addressable::URI.parse(id)

      if auri.fragment
        # TODO error handling fragment with invalid pointer
        ptr = JSI::JSON::Pointer.from_fragment('#' + auri.fragment)
        auri.fragment = nil
      else
        ptr = JSI::JSON::Pointer[]
      end

      if @schemas.key?(auri)
        ptr.evaluate(@schemas[auri])
      else
        raise(SchemaNotFound, "id #{id} not in JSI.schema.ids:\n#{JSI.schemas.ids.join("\n")}")
      end
    end
  end
end

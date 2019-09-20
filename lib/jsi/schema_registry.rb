module JSI
  class SchemaRegistry
    def initialize
      @schemas_by_id = {}
    end

    attr_reader :schemas_by_id

    def register(schema)
      unless schema.is_a?(JSI::Schema)
byebug
        raise(TypeError, "schema must be a JSI::Schema; got: #{schema.pretty_inspect}")
      end
      schema.schema_ids.each do |schema_id|
        if @schemas_by_id.key?(schema_id)
          unless @schemas_by_id[schema_id] == schema
            raise(RegistryError, "id collision on #{schema_id}. existing: \n#{@schemas_by_id[schema_id].pretty_inspect.chomp}\nnew:\n#{schema.pretty_inspect.chomp}")
          end
        else
          @schemas_by_id[schema_id] = schema
        end
      end
    end
  end
end

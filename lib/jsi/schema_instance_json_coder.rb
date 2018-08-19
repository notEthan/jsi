module JSI
  # this is a ActiveRecord serialization class intended to store JSON in the
  # database column and expose a ruby class once loaded on a model instance.
  # this allows for better ruby idioms to access to properties, and definition
  # of related methods on the loaded class.
  #
  # the first argument, `loaded_class`, is the class which will be used to
  # instantiate the column data. properties of the loaded class will correspond
  # to keys of the json object in the database.
  #
  # the column data may be either a single instance of the loaded class
  # (represented as one json object) or an array of them (represented as a json
  # array of json objects), indicated by the keyword argument `array`.
  #
  # the column behind the attribute may be an actual JSON column (postgres json
  # or jsonb - hstore should work too if you only have string attributes) or a
  # serialized string, indicated by the keyword argument `string`.
  class ObjectJSONCoder
    class Error < StandardError
    end
    class LoadError < Error
    end
    class DumpError < Error
    end

    def initialize(loaded_class, string: false, array: false, next_coder: nil)
      @loaded_class = loaded_class
      # this notes the order of the keys as they were in the json, used by dump_object to generate
      # json that is equivalent to the json/jsonifiable that came in, so that AR's #changed_attributes
      # can tell whether the attribute has been changed.
      @loaded_class.send(:attr_accessor, :object_json_coder_keys_order)
      @string = string
      @array = array
      @next_coder = next_coder
    end

    def load(column_data)
      return nil if column_data.nil?
      data = @string ? ::JSON.parse(column_data) : column_data
      object = if @array
        unless data.respond_to?(:to_ary)
          raise TypeError, "expected array-like column data; got: #{data.class}: #{data.inspect}"
        end
        data.map { |el| load_object(el) }
      else
        load_object(data)
      end
      object = @next_coder.load(object) if @next_coder
      object
    end

    def dump(object)
      object = @next_coder.dump(object) if @next_coder
      return nil if object.nil?
      jsonifiable = begin
        if @array
          unless object.respond_to?(:to_ary)
            raise DumpError, "expected array-like attribute; got: #{object.class}: #{object.inspect}"
          end
          object.map do |el|
            dump_object(el)
          end
        else
          dump_object(object)
        end
      end
      @string ? ::JSON.generate(jsonifiable) : jsonifiable
    end
  end
  # this is a ActiveRecord serialization class intended to store JSON in the
  # database column and expose a given SchemaInstanceBase subclass once loaded
  # on a model instance.
  class SchemaInstanceJSONCoder < ObjectJSONCoder
    private
    def load_object(data)
      @loaded_class.new(data)
    end

    def dump_object(object)
      JSI::Typelike.as_json(object)
    end
  end
end

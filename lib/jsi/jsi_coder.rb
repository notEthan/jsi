module JSI
  # this is a ActiveRecord serialization class intended to store JSON in the
  # database column and expose a given JSI::Base subclass once loaded
  # on a model instance.
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
  class JSICoder
    class Error < StandardError
    end
    class LoadError < Error
    end
    class DumpError < Error
    end

    # @param loaded_class [Class] the class to instantiate with database column data
    # @param array [Boolean] whether the column data represents one instance of loaded_class, or an array of them
    def initialize(loaded_class, array: false)
      @loaded_class = loaded_class
      # this notes the order of the keys as they were in the json, used by dump_object to generate
      # json that is equivalent to the json/jsonifiable that came in, so that AR's #changed_attributes
      # can tell whether the attribute has been changed.
      @loaded_class.send(:attr_accessor, :object_json_coder_keys_order)
      @array = array
    end

    # loads the database column to instances of #loaded_class
    #
    # @param data [Object] the raw json column data.
    # @return [loaded_class instance, Array<loaded_class instance>]
    def load(data)
      return nil if data.nil?
      object = if @array
        unless data.respond_to?(:to_ary)
          raise TypeError, "expected array-like column data; got: #{data.class}: #{data.inspect}"
        end
        data.map { |el| load_object(el) }
      else
        load_object(data)
      end
      object
    end

    # @param object[loaded_class instance, Array<loaded class instance>] data to be serialized to
    # @return [Object] data to write directly to the column
    def dump(object)
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
      jsonifiable
    end

    private
    # @param data [Object]
    # @return [loaded_class]
    def load_object(data)
      @loaded_class.new(data)
    end

    # @param object [loaded_class]
    # @return [Object]
    def dump_object(object)
      JSI::Typelike.as_json(object)
    end
  end
end

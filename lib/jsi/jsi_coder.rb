# frozen_string_literal: true

module JSI
  # this is an ActiveRecord serialization coder intended to serialize between
  # JSON-compatible objects on the database side, and a JSI instance loaded on
  # the model attribute.
  #
  # on its own this coder is useful with a JSON database column. in order to
  # serialize further to a string of JSON, or to YAML, the gem `arms` allows
  # coders to be chained together. for example, for a table `foos` and a column
  # `preferences_json` which is an actual json column, and `preferences_txt`
  # which is a string:
  #
  #     Preferences = JSI.new_schema_module(preferences_json_schema)
  #     class Foo < ActiveRecord::Base
  #       # as a single serializer, loads a Preferences instance from a json column
  #       serialize 'preferences_json', JSI::JSICoder.new(Preferences)
  #
  #       # for a text column, arms_serialize will go from JSI to JSON-compatible
  #       # objects to a string. the symbol `:jsi` is a shortcut for JSI::JSICoder.
  #       arms_serialize 'preferences_txt', [:jsi, Preferences], :json
  #     end
  #
  # the column data may be either a single instance of the schema class
  # (represented as one json object) or an array of them (represented as a json
  # array of json objects), indicated by the keyword argument `array`.
  class JSICoder
    # @param schema [#new_jsi] a Schema, SchemaSet, or JSI schema module. #load
    #   will instantiate column data using the JSI schemas represented.
    # @param array [Boolean] whether the dumped data represent one instance of the schema,
    #   or an array of them. note that it may be preferable to simply use an array schema.
    def initialize(schema, array: false)
      unless schema.respond_to?(:new_jsi)
        raise(ArgumentError, "schema param does not respond to #new_jsi: #{schema.inspect}")
      end
      @schema = schema
      @array = array
    end

    # loads the database column to JSI instances of our schema
    #
    # @param data [Object, Array, nil] the dumped schema instance(s) of the JSI(s)
    # @return [JSI::Base, Array<JSI::Base>, nil] the JSI or JSIs containing the schema
    #   instance(s), or nil if data is nil
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

    # dumps the object for the database
    # @param object [JSI::Base, Array<JSI::Base>, nil] the JSI or array of JSIs containing
    #   the schema instance(s)
    # @return [Object, Array, nil] the schema instance(s) of the JSI(s), or nil if object is nil
    def dump(object)
      return nil if object.nil?
      jsonifiable = begin
        if @array
          unless object.respond_to?(:to_ary)
            raise(TypeError, "expected array-like attribute; got: #{object.class}: #{object.inspect}")
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
    # @return [JSI::Base]
    def load_object(data)
      @schema.new_jsi(data)
    end

    # @param object [JSI::Base, Object]
    # @return [Object]
    def dump_object(object)
      JSI::Typelike.as_json(object)
    end
  end
end

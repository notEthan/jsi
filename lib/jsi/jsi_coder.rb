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
  #     Preferences = JSI.class_for_schema(preferences_json_schema)
  #     class Foo < ActiveRecord::Base
  #       # as a single serializer, loads a Preferences instance from a json column
  #       serialize 'preferences', JSI::JSICoder.new(Preferences)
  #
  #       # for a text column, arms_serialize will go from JSI to JSON-compatible
  #       # objects to a string. the symbol `:jsi` is a shortcut for JSI::JSICoder.
  #       arms_serialize 'preferences', [:jsi, Preferences], :json
  #     end
  #
  # the column data may be either a single instance of the loaded class
  # (represented as one json object) or an array of them (represented as a json
  # array of json objects), indicated by the keyword argument `array`.
  class JSICoder
    # @param loaded_class [Class] the JSI::Base subclass which #load will instantiate
    # @param array [Boolean] whether the dumped data represent one instance of loaded_class,
    #   or an array of them. note that it may be preferable to have loaded_class simply be
    #   an array schema class.
    def initialize(loaded_class, array: false)
      @loaded_class = loaded_class
      @array = array
    end

    # loads the database column to instances of #loaded_class
    #
    # @param data [Object, Array, nil] the dumped schema instance(s) of the JSI(s)
    # @return [loaded_class instance, Array<loaded_class instance>, nil] the JSI or JSIs
    #   containing the schema instance(s), or nil if data is nil
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

    # @param object [loaded_class instance, Array<loaded_class instance>, nil] the JSI or array
    #   of JSIs containing the schema instance(s)
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

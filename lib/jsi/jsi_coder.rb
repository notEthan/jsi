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
  class JSICoder
    # @param schema [#new_jsi] a Schema, SchemaSet, or JSI schema module. #load
    #   will instantiate column data using the JSI schemas represented.
    # @param jsi_opt [Hash] keyword arguments to pass to {Schema#new_jsi} when loading
    # @param as_json_opt [Hash] keyword arguments to pass to `#as_json` when dumping
    def initialize(schema, jsi_opt: Util::EMPTY_HASH, as_json_opt: Util::EMPTY_HASH)
      unless schema.respond_to?(:new_jsi)
        raise(ArgumentError, "schema param does not respond to #new_jsi: #{schema.inspect}")
      end
      @schema = schema
      @jsi_opt = jsi_opt
      @as_json_opt = as_json_opt
    end

    # loads database column data to JSI instance
    # @param data [Object, nil]
    # @return [Base, nil]
    def load(data)
      return nil if data.nil?
      @schema.new_jsi(data, **@jsi_opt)
    end

    # dumps the object for the database
    # @param object [Base, nil]
    # @return [Object, nil]
    def dump(object)
      JSI::Util.as_json(object, **@as_json_opt)
    end
  end
end

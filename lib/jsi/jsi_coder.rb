# frozen_string_literal: true

module JSI
  # this is an ActiveRecord serialization coder intended to serialize between
  # JSON-compatible objects on the database side, and a JSI instance loaded on
  # the model attribute.
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

module JSI
  # this is a ActiveRecord serialization class intended to store JSON in the
  # database column and expose a Struct subclass once loaded on a model instance.
  class StructJSONCoder < ObjectJSONCoder
    private
    def load_object(data)
      if data.is_a?(Hash)
        good_keys = @loaded_class.members.map(&:to_s)
        bad_keys = data.keys - good_keys
        unless bad_keys.empty?
          raise LoadError, "expected keys #{good_keys}; got unrecognized keys: #{bad_keys}"
        end
        instance = @loaded_class.new(*@loaded_class.members.map { |m| data[m.to_s] })
        instance.object_json_coder_keys_order = data.keys
        instance
      else
        raise LoadError, "expected instance(s) of #{Hash}; got: #{data.class}: #{data.inspect}"
      end
    end

    def dump_object(object)
      if object.is_a?(@loaded_class)
        keys = (object.object_json_coder_keys_order || []) | @loaded_class.members.map(&:to_s)
        keys.map { |member| {member => object[member]} }.inject({}, &:update)
      else
        raise TypeError, "expected instance(s) of #{@loaded_class}; got: #{object.class}: #{object.inspect}"
      end
    end
  end
end

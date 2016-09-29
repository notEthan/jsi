module Scorpio
  class Model
    def initialize(attributes = {}, options = {})
      unless attributes.is_a?(Hash)
        raise(ArgumentError, "attributes must be a hash; got: #{attributes.inspect}")
      end
      @attributes = attributes.map { |k,v| {k.is_a?(Symbol) ? k.to_s : k => v} }.inject({}, &:update)
      unless options.is_a?(Hash)
        raise(ArgumentError, "options must be a hash; got: #{options.inspect}")
      end
      @options = options.map { |k,v| {k.is_a?(Symbol) ? k.to_s : k => v} }.inject({}, &:update)
    end

    attr_reader :attributes
    attr_reader :options

    def [](key)
      @attributes[key]
    end

    def ==(other)
      @attributes == other.instance_eval { @attributes }
    end

    alias eql? ==

    def hash
      @attributes.hash
    end
  end
end

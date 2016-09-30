module Scorpio
  class Model
    class << self
      inheritable_accessors = {
        :resource_name => nil,
        :api_description => nil,
      }
      inheritable_accessors.each do |accessor, default_value|
        define_method(accessor) { default_value }
        define_method(:"#{accessor}=") do |id|
          singleton_class.instance_exec(id) do |id_|
            begin
              remove_method(accessor)
            rescue NameError
            end
            define_method(accessor) { id_ }
          end
        end
      end

      def set_api_description(api_description)
        self.api_description = api_description
        api_description['resources'][self.resource_name]['methods'].each do |method_name, method_desc|
          unless respond_to?(method_name)
            define_singleton_method(method_name) do |attributes = {}|
              call_api_method(method_name, attributes)
            end
          end
        end
      end

      def call_api_method(method_name, attributes = {})
        attributes = Scorpio.stringify_symbol_keys(attributes)
        method_desc = api_description['resources'][self.resource_name]['methods'][method_name]
        http_method = method_desc['httpMethod'].downcase.to_sym
        uri = method_desc['path']
        response = connection.run_request(http_method, uri, nil, nil).tap do |response|
          raise unless response.success?
        end
        response.body.map do |response_attributes|
          new(response_attributes)
        end
      end
    end

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

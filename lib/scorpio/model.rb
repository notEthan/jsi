require 'addressable/template'
module Scorpio
  class Model
    class << self
      inheritable_accessors = [
        [:api_description, nil],
        [:resource_name, nil, {update_methods: true}],
        [:schema_keys, [], {update_methods: true}],
        [:schemas_by_key, {}],
        [:schemas_by_id, {}],
        [:base_url, nil],
      ]
      inheritable_accessors.each do |(accessor, default_value, options)|
        define_method(accessor) { default_value }
        define_method(:"#{accessor}=") do |value|
          singleton_class.instance_exec(value) do |value_|
            begin
              remove_method(accessor)
            rescue NameError
            end
            define_method(accessor) { value_ }
          end
          if options && options[:update_methods]
            update_dynamic_methods
          end
        end
      end

      def set_api_description(api_description)
        # TODO full validation against google api rest description
        unless api_description.is_a?(Hash)
          raise ArgumentError, "given api description was not a hash; got: #{api_description.inspect}"
        end
        self.api_description = api_description
        (api_description['schemas'] || {}).each do |schema_key, schema|
          unless schema['id']
            raise ArgumentError, "schema #{schema_key} did not contain an id"
          end
          schemas_by_id[schema['id']] = schema
          schemas_by_key[schema_key] = schema
        end
        update_dynamic_methods
      end

      def update_dynamic_methods
        update_class_api_methods
        update_instance_accessors
      end

      def update_instance_accessors
        schemas_by_key.select { |k, _| schema_keys.include?(k) }.each do |schema_key, schema|
          unless schema['type'] == 'object'
            raise "schema key #{schema_key} for #{self} is not of type object - type must be object for Scorpio Model to represent this schema" # TODO class
          end
          schema['properties'].each do |property_name, property_schema|
            unless method_defined?(property_name)
              define_method(property_name) do
                self[property_name]
              end
            end
          end
        end
      end

      def update_class_api_methods
        if self.resource_name && api_description
          resource_api_methods = ((api_description['resources'] || {})[resource_name] || {})['methods'] || {}
          resource_api_methods.each do |method_name, method_desc|
            unless respond_to?(method_name)
              define_singleton_method(method_name) do |attributes = {}|
                call_api_method(method_name, attributes)
              end
            end
          end
        end
      end

      def deref_schema(schema)
        schema && schemas_by_id[schema['$ref']] || schema
      end

      MODULES_FOR_JSON_SCHEMA_TYPES = {
        'object' => [Hash],
        'array' => [Array, Set],
        'string' => [String],
        'integer' => [Integer],
        'number' => [Numeric],
        'boolean' => [TrueClass, FalseClass],
        'null' => [NilClass],
      }

      def call_api_method(method_name, attributes = {})
        attributes = Scorpio.stringify_symbol_keys(attributes)
        method_desc = api_description['resources'][self.resource_name]['methods'][method_name]
        http_method = method_desc['httpMethod'].downcase.to_sym
        path_template = Addressable::Template.new(method_desc['path'])
        missing_variables = path_template.variables - attributes.keys
        if missing_variables.any?
          raise(ArgumentError, "path #{method_desc['path']} for method #{method_name} requires attributes " +
            "which were missing: #{missing_variables.inspect}")
        end
        empty_variables = path_template.variables.select { |v| attributes[v].to_s.empty? }
        if empty_variables.any?
          raise(ArgumentError, "path #{method_desc['path']} for method #{method_name} requires attributes " +
            "which were empty: #{empty_variables.inspect}")
        end
        path = path_template.expand(attributes)
        url = Addressable::URI.parse(base_url) + path
        body = request_body_for_api_method(method_name, attributes)
        response = connection.run_request(http_method, url, body, nil).tap do |response|
          raise response.body.to_s unless response.success?
        end
        response_schema = method_desc['response']
        response_object_to_instances(response.body, response_schema)
      end

      def request_body_for_api_method(method_name, attributes)
        method_desc = (((api_description['resources'] || {})[resource_name] || {})['methods'] || {})[method_name]
        request_schema = deref_schema(method_desc['request'])
        if request_schema && request_schema['type'] == 'object'
          attributes
        else
          nil
        end
      end

      def response_object_to_instances(object, schema)
        schema = deref_schema(schema)
        if schema
          if schemas_by_key.any? { |key, as| as['id'] == schema['id'] && schema_keys.include?(key) }
            new(object)
          elsif schema['type'] == 'object' && MODULES_FOR_JSON_SCHEMA_TYPES['object'].any? { |m| object.is_a?(m) }
            object.map do |key, value|
              schema_for_value = schema['properties'][key] || schema['additionalProperties']
              {key => response_object_to_instances(value, schema_for_value)}
            end.inject({}, &:update)
          elsif schema['type'] == 'array' && MODULES_FOR_JSON_SCHEMA_TYPES['array'].any? { |m| object.is_a?(m) }
            object.map do |element|
              response_object_to_instances(element, schema['items'])
            end
          else
            object
          end
        else
          object
        end
      end
    end

    def initialize(attributes = {}, options = {})
      @attributes = Scorpio.stringify_symbol_keys(attributes)
      @options = Scorpio.stringify_symbol_keys(options)
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

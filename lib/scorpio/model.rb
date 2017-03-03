require 'addressable/template'
require 'json-schema'

module Scorpio
  class Model
    class << self
      def define_inheritable_accessor(accessor, options = {})
        if options[:default_getter]
          define_singleton_method(accessor, &options[:default_getter])
        else
          default_value = options[:default_value]
          define_singleton_method(accessor) { default_value }
        end
        define_singleton_method(:"#{accessor}=") do |value|
          singleton_class.instance_exec(value) do |value_|
            begin
              remove_method(accessor)
            rescue NameError
            end
            define_method(accessor) { value_ }
          end
          if options[:update_methods]
            update_dynamic_methods
          end
        end
      end
    end
    define_inheritable_accessor(:api_description)
    define_inheritable_accessor(:resource_name, update_methods: true)
    define_inheritable_accessor(:schema_keys, default_value: [], update_methods: true)
    define_inheritable_accessor(:schemas_by_key, default_value: {})
    define_inheritable_accessor(:schemas_by_id, default_value: {})
    define_inheritable_accessor(:base_url)

    define_inheritable_accessor(:faraday_request_middleware, default_value: [])
    define_inheritable_accessor(:faraday_adapter, default_getter: proc { Faraday.default_adapter })
    define_inheritable_accessor(:faraday_response_middleware, default_value: [])
    class << self
      def api_description_schema
        @api_description_schema ||= begin
          rest = YAML.load_file(Pathname.new(__FILE__).join('../../../getRest.yml'))
          rest['schemas'].each do |name, schema_hash|
            # URI hax because google doesn't put a URI in the id field properly
            schema = JSON::Schema.new(schema_hash, Addressable::URI.parse(''))
            JSON::Validator.add_schema(schema)
          end
          rest['schemas']['RestDescription']
        end
      end

      def set_api_description(api_description)
        JSON::Validator.validate!(api_description_schema, api_description)
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
        update_class_and_instance_api_methods
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
            unless method_defined?(:"#{property_name}=")
              define_method(:"#{property_name}=") do |value|
                self[property_name] = value
              end
            end
          end
        end
      end

      def update_class_and_instance_api_methods
        if self.resource_name && api_description
          resource_api_methods = ((api_description['resources'] || {})[resource_name] || {})['methods'] || {}
          resource_api_methods.each do |method_name, method_desc|
            # class method
            unless respond_to?(method_name)
              define_singleton_method(method_name) do |attributes = {}|
                call_api_method(method_name, attributes)
              end
            end

            # instance method
            unless method_defined?(method_name)
              request_schema = deref_schema(method_desc['request'])
              request_resource_is_self = request_schema &&
                request_schema['id'] &&
                schemas_by_key.any? { |key, as| as['id'] == request_schema['id'] && schema_keys.include?(key) }
              if request_resource_is_self
                define_method(method_name) do
                  call_api_method(method_name)
                end
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

      def connection
        Faraday.new do |c|
          unless faraday_request_middleware.any? { |m| [*m].first == :json }
            c.request :json
          end
          faraday_request_middleware.each do |m|
            c.request(*m)
          end
          c.adapter(*faraday_adapter)
          faraday_response_middleware.each do |m|
            c.response(*m)
          end
          unless faraday_response_middleware.any? { |m| [*m].first == :json }
            c.response :json, :content_type => /\bjson$/, :preserve_raw => true
          end
        end
      end

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
          error_class = Scorpio.error_classes_by_status[response.status]
          error_class ||= if (400..499).include?(response.status)
            ClientError
          elsif (500..599).include?(response.status)
            ServerError
          elsif !response.success?
            HTTPError
          end
          if error_class
            raise error_class.new(response.env[:raw_body]).tap { |e| e.response = response }
          end
        end
        response_schema = method_desc['response']
        response_object_to_instances(response.body, response_schema, 'persisted' => true)
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

      def response_object_to_instances(object, schema, initialize_options = {})
        schema = deref_schema(schema)
        if schema
          if schemas_by_key.any? { |key, as| as['id'] == schema['id'] && schema_keys.include?(key) }
            new(object, initialize_options)
          elsif schema['type'] == 'object' && MODULES_FOR_JSON_SCHEMA_TYPES['object'].any? { |m| object.is_a?(m) }
            object.map do |key, value|
              schema_for_value = schema['properties'] && schema['properties'][key] ||
                if schema['patternProperties']
                  _, pattern_schema = schema['patternProperties'].detect do |pattern, _|
                    key =~ Regexp.new(pattern)
                  end
                  pattern_schema
                end ||
                schema['additionalProperties']
              {key => response_object_to_instances(value, schema_for_value)}
            end.inject(object.class.new, &:update)
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

    def persisted?
      !!@options['persisted']
    end

    def [](key)
      @attributes[key]
    end

    def []=(key, value)
      @attributes[key] = value
    end

    def ==(other)
      @attributes == other.instance_eval { @attributes }
    end

    def call_api_method(method_name)
      self.class.call_api_method(method_name, self.attributes)
    end

    alias eql? ==

    def hash
      @attributes.hash
    end
  end
end

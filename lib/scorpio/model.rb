require 'addressable/template'
require 'json-schema'
require 'faraday_middleware'

module Scorpio
  # see also Faraday::Env::MethodsWithBodies
  METHODS_WITH_BODIES = %w(post put patch options)
  class RequestSchemaFailure < Error
  end

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
          singleton_class.instance_exec(value, self) do |value_, klass|
            begin
              remove_method(accessor)
            rescue NameError
            end
            define_method(accessor) { value_ }
            if options[:on_set]
              klass.instance_exec(&options[:on_set])
            end
          end
          if options[:update_methods]
            update_dynamic_methods
          end
        end
      end
    end
    define_inheritable_accessor(:api_description_class)
    define_inheritable_accessor(:api_description, on_set: proc { self.api_description_class = self })
    define_inheritable_accessor(:resource_name, update_methods: true)
    define_inheritable_accessor(:schema_keys, default_value: [], update_methods: true, on_set: proc do
      schema_keys.each do |key|
        api_description_class.models_by_schema_id = api_description_class.models_by_schema_id.merge(schemas_by_key[key]['id'] => self)
        api_description_class.models_by_schema_key = api_description_class.models_by_schema_key.merge(key => self)
      end
    end)
    define_inheritable_accessor(:schemas_by_key, default_value: {})
    define_inheritable_accessor(:schemas_by_id, default_value: {})
    define_inheritable_accessor(:models_by_schema_id, default_value: {})
    define_inheritable_accessor(:models_by_schema_key, default_value: {})
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

      def all_schema_properties
        schemas_by_key.select { |k, _| schema_keys.include?(k) }.map do |schema_key, schema|
          unless schema['type'] == 'object'
            raise "schema key #{schema_key} for #{self} is not of type object - type must be object for Scorpio Model to represent this schema" # TODO class
          end
          schema['properties'].keys
        end.inject([], &:|)
      end

      def update_instance_accessors
        all_schema_properties.each do |property_name|
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

      def update_class_and_instance_api_methods
        if self.resource_name && api_description
          resource_api_methods = ((api_description['resources'] || {})[resource_name] || {})['methods'] || {}
          resource_api_methods.each do |method_name, method_desc|
            # class method
            unless respond_to?(method_name)
              define_singleton_method(method_name) do |call_params = nil|
                call_api_method(method_name, call_params: call_params)
              end
            end

            # instance method
            unless method_defined?(method_name)
              request_schema = deref_schema(method_desc['request'])

              # define an instance method if the request schema is for this model 
              request_resource_is_self = request_schema &&
                request_schema['id'] &&
                schemas_by_key.any? { |key, as| as['id'] == request_schema['id'] && schema_keys.include?(key) }

              # also define an instance method depending on certain attributes the request description 
              # might have in common with the model's schema attributes
              request_attributes = []
              # if the path has attributes in common with model schema attributes, we'll define on 
              # instance method
              request_attributes |= Addressable::Template.new(method_desc['path']).variables
              # TODO if the method request schema has attributes in common with the model schema attributes,
              # should we define an instance method?
              #request_attributes |= request_schema && request_schema['type'] == 'object' && request_schema['properties'] ?
              #  request_schema['properties'].keys : []
              # TODO if the method parameters have attributes in common with the model schema attributes,
              # should we define an instance method?
              #request_attributes |= method_desc['parameters'] ? method_desc['parameters'].keys : []

              schema_attributes = schema_keys.map do |schema_key|
                schema = schemas_by_key[schema_key]
                schema['type'] == 'object' && schema['properties'] ? schema['properties'].keys : []
              end.inject([], &:|)

              if request_resource_is_self || (request_attributes & schema_attributes).any?
                define_method(method_name) do |call_params = nil|
                  call_api_method(method_name, call_params: call_params)
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

      def call_api_method(method_name, call_params: nil, model_attributes: nil)
        call_params = Scorpio.stringify_symbol_keys(call_params || {})
        model_attributes = Scorpio.stringify_symbol_keys(model_attributes || {})
        method_desc = api_description['resources'][self.resource_name]['methods'][method_name]
        http_method = method_desc['httpMethod'].downcase.to_sym
        path_template = Addressable::Template.new(method_desc['path'])
        template_params = model_attributes.merge(call_params)
        missing_variables = path_template.variables - call_params.keys - model_attributes.keys
        if missing_variables.any?
          raise(ArgumentError, "path #{method_desc['path']} for method #{method_name} requires attributes " +
            "which were missing: #{missing_variables.inspect}")
        end
        empty_variables = path_template.variables.select { |v| template_params[v].to_s.empty? }
        if empty_variables.any?
          raise(ArgumentError, "path #{method_desc['path']} for method #{method_name} requires attributes " +
            "which were empty: #{empty_variables.inspect}")
        end
        path = path_template.expand(template_params)
        url = Addressable::URI.parse(base_url) + path
        # assume that call_params must be included somewhere. model_attributes are a source of required things
        # but not required to be here.
        other_params = call_params.reject { |k, _| path_template.variables.include?(k) }

        method_desc = (((api_description['resources'] || {})[resource_name] || {})['methods'] || {})[method_name]
        request_schema = deref_schema(method_desc['request'])
        if request_schema
          # TODO deal with model_attributes / call_params better in nested whatever
          body = request_body_for_schema(model_attributes.merge(call_params), request_schema)
          body.update(call_params)
        else
          if other_params.any?
            if METHODS_WITH_BODIES.any? { |m| m == http_method.downcase }
              body = other_params
            else
              # TODO pay more attention to 'parameters' api method attribute
              url.query_values = other_params
            end
          end
        end

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
            message = "Error calling #{method_name} on #{self}:\n" + (response.env[:raw_body] || response.env.body)
            raise error_class.new(message).tap { |e| e.response = response }
          end
        end
        response_schema = method_desc['response']
        response_object_to_instances(response.body, response_schema, 'persisted' => true)
      end

      def request_body_for_schema(object, schema)
        schema = deref_schema(schema)
        if object.is_a?(Scorpio::Model)
          # TODO request_schema_fail unless schema is for given model type 
          request_body_for_schema(object.represent_for_schema(schema), schema)
        else
          if object.is_a?(Hash)
            object.map do |key, value|
              if schema
                if schema['type'] == 'object'
                  # TODO code dup with response_object_to_instances
                  if schema['properties'] && schema['properties'][key]
                    subschema = schema['properties'][key]
                    include_pair = true
                  else
                    if schema['patternProperties']
                      _, pattern_schema = schema['patternProperties'].detect do |pattern, _|
                        key =~ Regexp.new(pattern) # TODO map pattern to ruby syntax
                      end
                    end
                    if pattern_schema
                      subschema = pattern_schema
                      include_pair = true
                    else
                      if schema['additionalProperties'] == false
                        include_pair = false
                      elsif schema['additionalProperties'] == nil
                        # TODO decide on this (can combine with `else` if treating nil same as schema present)
                        include_pair = true
                        subschema = nil
                      else
                        include_pair = true
                        subschema = schema['additionalProperties']
                      end
                    end
                  end
                elsif schema['type']
                  request_schema_fail(object, schema)
                else
                  # TODO not sure
                  include_pair = true
                  subschema = nil
                end
              end
              if include_pair
                {key => request_body_for_schema(value, subschema)}
              else
                {}
              end
            end.inject({}, &:update)
          elsif object.is_a?(Array) || object.is_a?(Set)
            object.map do |el|
              if schema
                if schema['type'] == 'array'
                  # TODO index based subschema or whatever else works for array
                  subschema = schema['items']
                else
                  request_schema_fail(object, schema)
                end
              end
              request_body_for_schema(el, subschema)
            end
          else
            # TODO maybe raise on anything not jsonifiable 
            # TODO check conformance to schema, request_schema_fail if not
            object
          end
        end
      end

      def request_schema_fail(object, schema)
        raise(RequestSchemaFailure, "object does not conform to schema.\nobject = #{object.inspect}\nschema = #{JSON.pretty_generate(schema, quirks_mode: true)}")
      end

      def response_object_to_instances(object, schema, initialize_options = {})
        schema = deref_schema(schema)
        if schema
          if schema['type'] == 'object' && MODULES_FOR_JSON_SCHEMA_TYPES['object'].any? { |m| object.is_a?(m) }
            out = object.map do |key, value|
              schema_for_value = schema['properties'] && schema['properties'][key] ||
                if schema['patternProperties']
                  _, pattern_schema = schema['patternProperties'].detect do |pattern, _|
                    key =~ Regexp.new(pattern)
                  end
                  pattern_schema
                end ||
                schema['additionalProperties']
              {key => response_object_to_instances(value, schema_for_value, initialize_options)}
            end.inject(object.class.new, &:update)
            model = models_by_schema_id[schema['id']]
            if model
              model.new(out, initialize_options)
            else
              out
            end
          elsif schema['type'] == 'array' && MODULES_FOR_JSON_SCHEMA_TYPES['array'].any? { |m| object.is_a?(m) }
            object.map do |element|
              response_object_to_instances(element, schema['items'], initialize_options)
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
      @persisted = !!@options['persisted']
    end

    attr_reader :attributes
    attr_reader :options

    def persisted?
      @persisted
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

    def call_api_method(method_name, call_params: nil)
      response = self.class.call_api_method(method_name, call_params: call_params, model_attributes: self.attributes)

      # if we're making a POST or PUT and the request schema is this resource, we'll assume that
      # the request is persisting this resource
      api_method = self.class.api_description['resources'][self.class.resource_name]['methods'][method_name]
      request_schema = self.class.deref_schema(api_method['request'])
      request_resource_is_self = request_schema &&
        request_schema['id'] &&
        self.class.schemas_by_key.any? { |key, as| as['id'] == request_schema['id'] && self.class.schema_keys.include?(key) }
      response_schema = self.class.deref_schema(api_method['response'])
      response_resource_is_self = response_schema &&
        response_schema['id'] &&
        self.class.schemas_by_key.any? { |key, as| as['id'] == response_schema['id'] && self.class.schema_keys.include?(key) }
      if request_resource_is_self && %w(PUT POST).include?(api_method['httpMethod'])
        @persisted = true

        if response_resource_is_self
          @attributes = response.attributes
        end
      end

      response
    end

    # TODO
    def represent_for_schema(schema)
      @attributes
    end

    alias eql? ==

    def hash
      @attributes.hash
    end
  end
end

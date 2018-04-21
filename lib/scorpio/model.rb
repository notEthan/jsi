require 'addressable/template'
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
          # the value before the field is set (overwritten) is the result of the default_getter proc
          define_singleton_method(accessor, &options[:default_getter])
        else
          # the value before the field is set (overwritten) is the default_value (which is nil if not specified)
          default_value = options[:default_value]
          define_singleton_method(accessor) { default_value }
        end
        # field setter method. redefines the getter, replacing the method with one that returns the
        # setter's argument (that being inherited to the scope of the define_method(accessor) block
        define_singleton_method(:"#{accessor}=") do |value|
          # the setter operates on the singleton class of the receiver (self)
          singleton_class.instance_exec(value, self) do |value_, klass|
            # remove a previous getter. NameError is raised if a getter is not defined on this class;
            # this may be ignored.
            begin
              remove_method(accessor)
            rescue NameError
            end
            # getter method
            define_method(accessor) { value_ }
            # invoke on_set callback defined on the class
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
    # the class on which the openapi document is defined. subclasses use the openapi document set on this class
    # (except in the unlikely event it is overwritten by a subclass)
    define_inheritable_accessor(:openapi_document_class)
    # the openapi document
    define_inheritable_accessor(:openapi_document, on_set: proc { self.openapi_document_class = self })
    define_inheritable_accessor(:resource_name, update_methods: true)
    define_inheritable_accessor(:definition_keys, default_value: [], update_methods: true, on_set: proc do
      definition_keys.each do |key|
        schema_as_key = schemas_by_key[key]
        schema_as_key = schema_as_key.object if schema_as_key.is_a?(Scorpio::OpenAPI::Schema)
        schema_as_key = schema_as_key.content if schema_as_key.is_a?(Scorpio::JSON::Node)

        openapi_document_class.models_by_schema = openapi_document_class.models_by_schema.merge(schema_as_key => self)
      end
    end)
    define_inheritable_accessor(:schemas_by_key, default_value: {})
    define_inheritable_accessor(:schemas_by_path)
    define_inheritable_accessor(:schemas_by_id, default_value: {})
    define_inheritable_accessor(:models_by_schema, default_value: {})
    define_inheritable_accessor(:base_url)

    define_inheritable_accessor(:faraday_request_middleware, default_value: [])
    define_inheritable_accessor(:faraday_adapter, default_getter: proc { Faraday.default_adapter })
    define_inheritable_accessor(:faraday_response_middleware, default_value: [])
    class << self
      def set_openapi_document(openapi_document)
        if openapi_document.is_a?(Hash)
          openapi_document = OpenAPI::Document.new(openapi_document)
        end
        openapi_document.paths.each do |path, path_item|
          path_item.each do |http_method, operation|
            next if http_method == 'parameters' # parameters is not an operation. TOOD maybe just select the keys that are http methods?
            unless operation.is_a?(Scorpio::OpenAPI::Operation)
              raise("bad operation at #{operation.fragment}: #{operation.pretty_inspect}")
            end
            operation.path = path
            operation.http_method = http_method
          end
        end

        openapi_document.validate!
        self.schemas_by_path = {}
        self.schemas_by_key = {}
        self.schemas_by_id = {}
        self.openapi_document = openapi_document
        (openapi_document.definitions || {}).each do |schema_key, schema|
          if schema['id']
            # this isn't actually allowed by openapi's definition. whatever.
            self.schemas_by_id = self.schemas_by_id.merge(schema['id'] => schema)
          end
          self.schemas_by_path = self.schemas_by_path.merge(schema.object.fragment => schema)
          self.schemas_by_key = self.schemas_by_key.merge(schema_key => schema)
        end
        update_dynamic_methods
      end

      def update_dynamic_methods
        update_class_and_instance_api_methods
        update_instance_accessors
      end

      def all_schema_properties
        schemas_by_key.select { |k, _| definition_keys.include?(k) }.map do |schema_key, schema|
          unless schema['type'] == 'object'
            raise "definition key #{schema_key} for #{self} is not of type object - type must be object for Scorpio Model to represent this schema" # TODO class
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

      def operation_for_resource_class?(operation)
        return false unless resource_name

        return true if operation['x-resource'] == self.resource_name

        return true if operation.operationId =~ /\A#{Regexp.escape(resource_name)}\.(\w+)\z/

        request_schema = operation.body_parameter['schema'] if operation.body_parameter
        if request_schema && schemas_by_key.any? { |key, as| as == request_schema && definition_keys.include?(key) }
          return true
        end

        return false
      end

      def operation_for_resource_instance?(operation)
        return false unless operation_for_resource_class?(operation)

        request_schema = operation.body_parameter['schema'] if operation.body_parameter

        # define an instance method if the request schema is for this model 
        request_resource_is_self = request_schema &&
          schemas_by_key.any? { |key, as| as == request_schema && definition_keys.include?(key) }

        # also define an instance method depending on certain attributes the request description 
        # might have in common with the model's schema attributes
        request_attributes = []
        # if the path has attributes in common with model schema attributes, we'll define on 
        # instance method
        request_attributes |= Addressable::Template.new(operation.path).variables
        # TODO if the method request schema has attributes in common with the model schema attributes,
        # should we define an instance method?
        #request_attributes |= request_schema && request_schema['type'] == 'object' && request_schema['properties'] ?
        #  request_schema['properties'].keys : []
        # TODO if the method parameters have attributes in common with the model schema attributes,
        # should we define an instance method?
        #request_attributes |= method_desc['parameters'] ? method_desc['parameters'].keys : []

        schema_attributes = definition_keys.map do |schema_key|
          schema = schemas_by_key[schema_key]
          schema['type'] == 'object' && schema['properties'] ? schema['properties'].keys : []
        end.inject([], &:|)

        return request_resource_is_self || (request_attributes & schema_attributes).any?
      end

      def method_names_by_operation
        @method_names_by_operation ||= Hash.new do |h, operation|
          h[operation] = begin
            raise(ArgumentError, operation.pretty_inspect) unless operation.is_a?(Scorpio::OpenAPI::Operation)
            if operation['x-resource-method']
              method_name = operation['x-resource-method']
            elsif resource_name && operation.operationId =~ /\A#{Regexp.escape(resource_name)}\.(\w+)\z/
              method_name = $1
            else
              method_name = operation.operationId || raise("no operationId on operation: #{operation.pretty_inspect}")
            end
            method_name = '_' + method_name unless method_name[/\A[a-zA-Z_]/]
            method_name.gsub(/[^\w]/, '_')
          end
        end
      end

      def update_class_and_instance_api_methods
        openapi_document.paths.each do |path, path_item|
          path_item.each do |http_method, operation|
            next if http_method == 'parameters' # parameters is not an operation. TOOD maybe just select the keys that are http methods?
            operation.path = path
            operation.http_method = http_method
            method_name = method_names_by_operation[operation]
            # class method
            if operation_for_resource_class?(operation) && !respond_to?(method_name)
              define_singleton_method(method_name) do |call_params = nil|
                call_operation(operation, call_params: call_params)
              end
            end

            # instance method
            if operation_for_resource_instance?(operation) && !method_defined?(method_name)
              define_method(method_name) do |call_params = nil|
                call_operation(operation, call_params: call_params)
              end
            end
          end
        end
      end

      def deref_schema(schema)
        schema = schema.object if schema.is_a?(Scorpio::SchemaObjectBase)
        schema = schema.deref if schema.is_a?(Scorpio::JSON::Node)
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
          faraday_response_middleware.each do |m|
            c.response(*m)
          end
          unless faraday_response_middleware.any? { |m| [*m].first == :json }
            c.response :json, :content_type => /\bjson$/, :preserve_raw => true
          end
          c.adapter(*faraday_adapter)
        end
      end

      def call_operation(operation, call_params: nil, model_attributes: nil)
        call_params = Scorpio.stringify_symbol_keys(call_params) if call_params.is_a?(Hash)
        model_attributes = Scorpio.stringify_symbol_keys(model_attributes || {})
        http_method = operation.http_method.downcase.to_sym
        path_template = Addressable::Template.new(operation.path)
        template_params = model_attributes
        template_params = template_params.merge(call_params) if call_params.is_a?(Hash)
        missing_variables = path_template.variables - template_params.keys
        if missing_variables.any?
          raise(ArgumentError, "path #{operation.path} for operation #{operation.operationId} requires attributes " +
            "which were missing: #{missing_variables.inspect}")
        end
        empty_variables = path_template.variables.select { |v| template_params[v].to_s.empty? }
        if empty_variables.any?
          raise(ArgumentError, "path #{operation.path} for operation #{operation.operationId} requires attributes " +
            "which were empty: #{empty_variables.inspect}")
        end
        path = path_template.expand(template_params)
        url = Addressable::URI.parse(base_url) + path
        # assume that call_params must be included somewhere. model_attributes are a source of required things
        # but not required to be here.
        other_params = call_params
        if other_params.is_a?(Hash)
          other_params.reject! { |k, _| path_template.variables.include?(k) }
        end

        request_schema = operation.body_parameter && deref_schema(operation.body_parameter['schema'])
        if request_schema
          # TODO deal with model_attributes / call_params better in nested whatever
          if call_params.nil?
            body = request_body_for_schema(model_attributes, request_schema)
          elsif call_params.is_a?(Hash)
            body = request_body_for_schema(model_attributes.merge(call_params), request_schema)
            body.update(call_params)
          else
            body = call_params
          end
        else
          if other_params
            if METHODS_WITH_BODIES.any? { |m| m.to_s == http_method.downcase.to_s }
              body = other_params
            else
              if other_params.is_a?(Hash)
                # TODO pay more attention to 'parameters' api method attribute
                url.query_values = other_params
              else
                raise
              end
            end
          end
        end

        response = connection.run_request(http_method, url, body, nil)
        response_object = response.body

        error_class = Scorpio.error_classes_by_status[response.status]
        error_class ||= if (400..499).include?(response.status)
          ClientError
        elsif (500..599).include?(response.status)
          ServerError
        elsif !response.success?
          HTTPError
        end
        if error_class
          message = "Error calling operation #{operation.operationId} on #{self}:\n" + (response.env[:raw_body] || response.env.body)
          raise(error_class.new(message).tap do |e|
            e.faraday_response = response
            e.response_object = response_object
          end)
        end

        if operation.responses
          _, operation_response = operation.responses.detect { |k, v| k.to_s == response.status.to_s }
          operation_response ||= operation.responses['default']
          response_schema = operation_response.schema if operation_response
        end
        initialize_options = {
          'persisted' => true,
          'source' => {'operationId' => operation.operationId, 'call_params' => call_params, 'url' => url.to_s},
          'response' => response,
        }
        response_object_to_instances(response_object, response_schema, initialize_options)
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
        raise(RequestSchemaFailure, "object does not conform to schema.\nobject = #{object.pretty_inspect}\nschema = #{::JSON.pretty_generate(schema, quirks_mode: true)}")
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
            schema_as_key = schema
            schema_as_key = schema_as_key.object if schema_as_key.is_a?(Scorpio::OpenAPI::Schema)
            schema_as_key = schema_as_key.content if schema_as_key.is_a?(Scorpio::JSON::Node)
            model = models_by_schema[schema_as_key]
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

    def call_api_method(method_name, call_params: nil)
      operation = self.class.method_names_by_operation.invert[method_name] || raise(ArgumentError)
      call_operation(operation, call_params: call_params)
    end

    def call_operation(operation, call_params: nil)
      response = self.class.call_operation(operation, call_params: call_params, model_attributes: self.attributes)

      # if we're making a POST or PUT and the request schema is this resource, we'll assume that
      # the request is persisting this resource
      request_schema = operation.body_parameter && self.class.deref_schema(operation.body_parameter['schema'])
      request_resource_is_self = request_schema &&
        request_schema['id'] &&
        self.class.schemas_by_key.any? { |key, as| (as['id'] ? as['id'] == request_schema['id'] : as == request_schema) && self.class.definition_keys.include?(key) }
      if @options['response'] && @options['response'].status && operation.responses
        _, response_schema = operation.responses.detect { |k, v| k.to_s == @options['response'].status.to_s }
      end
      response_schema = self.class.deref_schema(response_schema)
      response_resource_is_self = response_schema &&
        self.class.schemas_by_key.any? { |key, as| (as['id'] ? as['id'] == response_schema['id'] : as == response_schema) && self.class.definition_keys.include?(key) }
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

    def inspect
      "\#<#{self.class.name} #{attributes.inspect}>"
    end
    def pretty_print(q)
      q.instance_exec(self) do |obj|
        text "\#<#{obj.class.name}"
        group_sub {
          nest(2) {
            breakable ' '
            pp obj.attributes
          }
        }
        breakable ''
        text '>'
      end
    end

    def fingerprint
      {class: self.class, attributes: @attributes}
    end
    include FingerprintHash
  end
end

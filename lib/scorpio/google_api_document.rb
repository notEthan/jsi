require 'api_hammer/ycomb'
require 'scorpio/schema_object_base'
require 'yaml'

module Scorpio
  module Google
    apidoc_schema_doc = YAML.load_file(File.join(File.dirname(__FILE__), '../../getRest.yml'))
    api_document_class = proc do |key|
      Scorpio.class_for_schema(apidoc_schema_doc['schemas'][key], apidoc_schema_doc)
    end

    # naming these is not strictly necessary, but is nice to have.
    # generated: puts Scorpio::Google::ApiDocument.document['schemas'].select { |k,v| v['type'] == 'object' }.keys.map { |k| "#{k[0].upcase}#{k[1..-1]} = api_document_class.call('#{k}')" }
    DirectoryList   = api_document_class.call('DirectoryList')
    JsonSchema      = api_document_class.call('JsonSchema')
    RestDescription = api_document_class.call('RestDescription')
    RestMethod      = api_document_class.call('RestMethod')
    RestResource    = api_document_class.call('RestResource')

    class RestDescription
      def to_openapi_document
        Scorpio::OpenAPI::Document.new(to_openapi_hash)
      end

      def to_openapi_hash
        ad = self
        ad_methods = []
        if ad['methods']
          ad_methods += ad['methods'].map do |mn, m|
            m.class.new(m.object.merge('method_name' => mn))
          end
        end
        ad_methods += ad.resources.map do |rn, r|
          (r['methods'] || {}).map { |mn, m| m.class.new(m.object.merge('resource_name' => rn, 'method_name' => mn)) }
        end.inject([], &:+)

        paths = ad_methods.group_by { |m| m['path'] }.map do |path, path_methods|
          unless path =~ %r(\A/)
            path = '/' + path
          end
          operations = path_methods.group_by { |m| m['httpMethod'] }.map do |http_method, http_method_methods|
            if http_method_methods.size > 1
              #raise("http method #{http_method} at path #{path} not unique: #{http_method_methods.inspect}")
            end
            method = http_method_methods.first
            unused_path_params = Addressable::Template.new(path).variables
            {http_method.downcase => {}.tap do |operation|
              #operation['tags'] = []
              #operation['summary'] = 
              operation['description'] = method['description'] if method['description']
              if method['resource_name']
                operation['x-resource'] = method['resource_name']
                operation['x-resource-method'] = method['method_name']
              end
              #operation['externalDocs'] = 
              operation['operationId'] = method['id'] || (method['resource_name'] ? "#{method['resource_name']}.#{method['method_name']}" : method['method_name'])
              #operation['produces'] = 
              #operation['consumes'] = 
              if method['parameters']
                operation['parameters'] = method['parameters'].map do |name, parameter|
                  {}.tap do |op_param|
                    op_param['description'] = parameter.description if parameter.description
                    op_param['name'] = name
                    op_param['in'] = if parameter.location
                      parameter.location
                    elsif unused_path_params.include?(name)
                      'path'
                    else
                      'query'
                    # unused: header, formdata, body
                    end
                    unused_path_params.delete(name) if op_param['in'] == 'path'
                    op_param['required'] = parameter.object.key?('required') ? parameter['required'] : op_param['in'] == 'path' ? true : false
                    op_param['type'] = parameter.type || 'string'
                    op_param['format'] = parameter.format if parameter.format
                  end
                end
              end
              if unused_path_params.any?
                operation['parameters'] ||= []
                operation['parameters'] += unused_path_params.map do |param_name|
                  {
                    name: param_name,
                    in: 'path',
                    required: true,
                    type: 'string',
                  }
                end
              end
              if method['request']
                operation['parameters'] ||= []
                operation['parameters'] << {
                  name: 'body',
                  in: 'body',
                  required: true,
                  schema: method['request'].object,
                }
              end
              if method['response']
                operation['responses'] = {
                  'default' => {
                    description: 'default response',
                    schema: method['response'].object,
                  },
                }
              end
            end}
          end.inject({}, &:update)

          {path => operations}
        end.inject({}, &:update)

        openapi = {
          swagger: '2.0',
          info: { #/definitions/info
            title: ad.title || ad.name,
            description: ad.description,
            version: ad.version || '',
            #termsOfService: '',
            contact: {
              name: ad.ownerName,
              #url: 
              #email: '',
            },
            #license: {
              #name: '',
              #url: '',
            #},
          },
          host: ad.rootUrl ? Addressable::URI.parse(ad.rootUrl).host : ad.baseUrl ? Addressable::URI.parse(ad.rootUrl).host : ad.name, # uhh ... got nothin' better 
          basePath: begin
            path = ad.servicePath || ad.basePath || (ad.baseUrl ? Addressable::URI.parse(ad.baseUrl).path : '/')
            path =~ %r(\A/) ? path : "/" + path
          end,
          schemes: ad.rootUrl ? [Addressable::URI.parse(ad.rootUrl).scheme] : ad.baseUrl ? [Addressable::URI.parse(ad.rootUrl).scheme] : [], #/definitions/schemesList
          consumes: ['application/json'], # we'll just make this assumption
          produces: ['application/json'],
          paths: paths, #/definitions/paths
        }
        if ad.schemas
          openapi['definitions'] = {}
          ad.schemas.each do |name, schema|
            openapi['definitions'][name] = schema.object.reject { |k, v| k == 'id' }
          end
          ad.schemas.each do |name, schema|
            openapi = ycomb do |rec|
              proc do |object|
                if object.respond_to?(:to_hash)
                  if object['$ref'] && (object['$ref'] == schema['id'] || object['$ref'] == "#/schemas/#{name}" || object['$ref'] == name)
                    object.map { |k, v| {k => k == '$ref' ? "#/definitions/#{name}" : rec.call(v)} }.inject({}, &:update)
                  else
                    object.map { |k, v| {k => rec.call(v)} }.inject({}, &:update)
                  end
                elsif object.respond_to?(:to_ary)
                  object.map(&rec)
                else
                  object
                end
              end
            end.call(openapi)
          end
        end
        # check we haven't got anything that shouldn't go in a openapi document
        openapi = ycomb do |rec|
          proc do |object|
            if object.is_a?(Hash)
              object.map { |k, v| {rec.call(k) => rec.call(v)} }.inject({}, &:update)
            elsif object.is_a?(Array)
              object.map(&rec)
            elsif object.is_a?(Symbol)
              object.to_s
            elsif [String, TrueClass, FalseClass, NilClass, Numeric].any? { |c| object.is_a?(c) }
              object
            else
              raise(object.inspect)
            end
          end
        end.call(openapi)
      end
    end
  end
end

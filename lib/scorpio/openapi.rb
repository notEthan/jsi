require 'scorpio/schema_object_base'

module Scorpio
  module OpenAPI
    openapi_schema_doc = ::JSON.parse(Scorpio.root.join('documents/swagger.io/v2/schema.json').read)
    openapi_class = proc do |definitions_key|
      Scorpio.class_for_schema(Scorpio::JSON::Node.new(openapi_schema_doc, ['definitions', definitions_key]))
    end

    Document = Scorpio.class_for_schema(Scorpio::JSON::Node.new(openapi_schema_doc, []))

    # naming these is not strictly necessary, but is nice to have.
    # generated: puts Scorpio::OpenAPI::Document.document['definitions'].select { |k,v| v['type'] == 'object' }.keys.map { |k| "#{k[0].upcase}#{k[1..-1]} = openapi_class.call('#{k}')" }
    Info                        = openapi_class.call('info')
    Contact                     = openapi_class.call('contact')
    License                     = openapi_class.call('license')
    Paths                       = openapi_class.call('paths')
    Definitions                 = openapi_class.call('definitions')
    ParameterDefinitions        = openapi_class.call('parameterDefinitions')
    ResponseDefinitions         = openapi_class.call('responseDefinitions')
    ExternalDocs                = openapi_class.call('externalDocs')
    Examples                    = openapi_class.call('examples')
    Operation                   = openapi_class.call('operation')
    PathItem                    = openapi_class.call('pathItem')
    Responses                   = openapi_class.call('responses')
    Response                    = openapi_class.call('response')
    Headers                     = openapi_class.call('headers')
    Header                      = openapi_class.call('header')
    BodyParameter               = openapi_class.call('bodyParameter')
    NonBodyParameter            = openapi_class.call('nonBodyParameter')
    Schema                      = openapi_class.call('schema')
    FileSchema                  = openapi_class.call('fileSchema')
    PrimitivesItems             = openapi_class.call('primitivesItems')
    SecurityRequirement         = openapi_class.call('securityRequirement')
    Xml                         = openapi_class.call('xml')
    Tag                         = openapi_class.call('tag')
    SecurityDefinitions         = openapi_class.call('securityDefinitions')
    BasicAuthenticationSecurity = openapi_class.call('basicAuthenticationSecurity')
    ApiKeySecurity              = openapi_class.call('apiKeySecurity')
    Oauth2ImplicitSecurity      = openapi_class.call('oauth2ImplicitSecurity')
    Oauth2PasswordSecurity      = openapi_class.call('oauth2PasswordSecurity')
    Oauth2ApplicationSecurity   = openapi_class.call('oauth2ApplicationSecurity')
    Oauth2AccessCodeSecurity    = openapi_class.call('oauth2AccessCodeSecurity')
    Oauth2Scopes                = openapi_class.call('oauth2Scopes')
    JsonReference               = openapi_class.call('jsonReference')

    class Operation
      attr_accessor :path
      attr_accessor :http_method

      # there should only be one body parameter; this returns it
      def body_parameter
        (parameters || []).detect do |parameter|
          parameter['in'] == 'body'
        end
      end
    end
  end
end

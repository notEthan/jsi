require 'scorpio/schema_object_base'

module Scorpio
  module OpenAPI
    openapi_schema_doc = ::JSON.parse(Scorpio.root.join('documents/swagger.io/v2/schema.json').read)
    openapi_class = proc do |*key|
      Scorpio.class_for_schema(Scorpio::JSON::Node.new_by_type(openapi_schema_doc, key))
    end

    Document = openapi_class.call()

    # naming these is not strictly necessary, but is nice to have.
    # generated: puts Scorpio::OpenAPI::Document.schema_document['definitions'].select { |k,v| ['object', nil].include?(v['type']) }.keys.map { |k| "#{k[0].upcase}#{k[1..-1]} = openapi_class.call('definitions', '#{k}')" }
    Info                        = openapi_class.call('definitions', 'info')
    Contact                     = openapi_class.call('definitions', 'contact')
    License                     = openapi_class.call('definitions', 'license')
    Paths                       = openapi_class.call('definitions', 'paths')
    Definitions                 = openapi_class.call('definitions', 'definitions')
    ParameterDefinitions        = openapi_class.call('definitions', 'parameterDefinitions')
    ResponseDefinitions         = openapi_class.call('definitions', 'responseDefinitions')
    ExternalDocs                = openapi_class.call('definitions', 'externalDocs')
    Examples                    = openapi_class.call('definitions', 'examples')
    Operation                   = openapi_class.call('definitions', 'operation')
    PathItem                    = openapi_class.call('definitions', 'pathItem')
    Responses                   = openapi_class.call('definitions', 'responses')
    ResponseValue               = openapi_class.call('definitions', 'responseValue')
    Response                    = openapi_class.call('definitions', 'response')
    Headers                     = openapi_class.call('definitions', 'headers')
    Header                      = openapi_class.call('definitions', 'header')
    VendorExtension             = openapi_class.call('definitions', 'vendorExtension')
    BodyParameter               = openapi_class.call('definitions', 'bodyParameter')
    HeaderParameterSubSchema    = openapi_class.call('definitions', 'headerParameterSubSchema')
    QueryParameterSubSchema     = openapi_class.call('definitions', 'queryParameterSubSchema')
    FormDataParameterSubSchema  = openapi_class.call('definitions', 'formDataParameterSubSchema')
    PathParameterSubSchema      = openapi_class.call('definitions', 'pathParameterSubSchema')
    NonBodyParameter            = openapi_class.call('definitions', 'nonBodyParameter')
    Parameter                   = openapi_class.call('definitions', 'parameter')
    Schema                      = openapi_class.call('definitions', 'schema')
    FileSchema                  = openapi_class.call('definitions', 'fileSchema')
    PrimitivesItems             = openapi_class.call('definitions', 'primitivesItems')
    SecurityRequirement         = openapi_class.call('definitions', 'securityRequirement')
    Xml                         = openapi_class.call('definitions', 'xml')
    Tag                         = openapi_class.call('definitions', 'tag')
    SecurityDefinitions         = openapi_class.call('definitions', 'securityDefinitions')
    BasicAuthenticationSecurity = openapi_class.call('definitions', 'basicAuthenticationSecurity')
    ApiKeySecurity              = openapi_class.call('definitions', 'apiKeySecurity')
    Oauth2ImplicitSecurity      = openapi_class.call('definitions', 'oauth2ImplicitSecurity')
    Oauth2PasswordSecurity      = openapi_class.call('definitions', 'oauth2PasswordSecurity')
    Oauth2ApplicationSecurity   = openapi_class.call('definitions', 'oauth2ApplicationSecurity')
    Oauth2AccessCodeSecurity    = openapi_class.call('definitions', 'oauth2AccessCodeSecurity')
    Oauth2Scopes                = openapi_class.call('definitions', 'oauth2Scopes')
    Title                       = openapi_class.call('definitions', 'title')
    Description                 = openapi_class.call('definitions', 'description')
    Default                     = openapi_class.call('definitions', 'default')
    MultipleOf                  = openapi_class.call('definitions', 'multipleOf')
    Maximum                     = openapi_class.call('definitions', 'maximum')
    ExclusiveMaximum            = openapi_class.call('definitions', 'exclusiveMaximum')
    Minimum                     = openapi_class.call('definitions', 'minimum')
    ExclusiveMinimum            = openapi_class.call('definitions', 'exclusiveMinimum')
    MaxLength                   = openapi_class.call('definitions', 'maxLength')
    MinLength                   = openapi_class.call('definitions', 'minLength')
    Pattern                     = openapi_class.call('definitions', 'pattern')
    MaxItems                    = openapi_class.call('definitions', 'maxItems')
    MinItems                    = openapi_class.call('definitions', 'minItems')
    UniqueItems                 = openapi_class.call('definitions', 'uniqueItems')
    Enum                        = openapi_class.call('definitions', 'enum')
    JsonReference               = openapi_class.call('definitions', 'jsonReference')

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

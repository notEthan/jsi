# frozen_string_literal: true

module JSI
  metaschema_document = ::JSON.parse(SCHEMAS_PATH.join('json-schema.org/draft-07/schema.json').read)
  JSONSchemaOrgDraft07 = JSI.new_metaschema_module(metaschema_document,
    schema_implementation_modules: [JSI::Schema::Draft07],
  )

  # the JSI schema module for `http://json-schema.org/draft-07/schema`
  module JSONSchemaOrgDraft07
    # @!parse extend JSI::SchemaModule::DescribesSchemaModule
    # @!parse include JSI::Schema::Draft07


    Id     = properties['$id']
    Xschema = properties['$schema']
    Ref      = properties['$ref']
    Comment   = properties['$comment']
    Title      = properties['title']
    Description = properties['description']
    Default     = properties['default']
    ReadOnly     = properties['readOnly']
    Examples      = properties['examples']
    MultipleOf     = properties['multipleOf']
    Maximum         = properties['maximum']
    ExclusiveMaximum = properties['exclusiveMaximum']
    Minimum          = properties['minimum']
    ExclusiveMinimum = properties['exclusiveMinimum']
    MaxLength       = properties['maxLength']
    MinLength      = properties['minLength']
    Pattern        = properties['pattern']
    AdditionalItems = properties['additionalItems']
    Items          = properties['items']
    MaxItems      = properties['maxItems']
    MinItems       = properties['minItems']
    UniqueItems     = properties['uniqueItems']
    Contains         = properties['contains']
    MaxProperties     = properties['maxProperties']
    MinProperties      = properties['minProperties']
    Required            = properties['required']
    AdditionalProperties = properties['additionalProperties']
    Definitions         = properties['definitions']
    Properties         = properties['properties']
    PatternProperties = properties['patternProperties']
    Dependencies     = properties['dependencies']
    PropertyNames   = properties['propertyNames']
    Const          = properties['const']
    Enum          = properties['enum']
    Type           = properties['type']
    Format          = properties['format']
    ContentMediaType = properties['contentMediaType']
    ContentEncoding = properties['contentEncoding']
    If             = properties['if']
    Then          = properties['then']
    Else         = properties['else']
    AllOf       = properties['allOf']
    AnyOf      = properties['anyOf']
    OneOf     = properties['oneOf']
    Not      = properties['not']

    SchemaArray              = definitions['schemaArray']
    NonNegativeInteger        = definitions['nonNegativeInteger']
    NonNegativeIntegerDefault0 = definitions['nonNegativeIntegerDefault0']
    SimpleType                = definitions['simpleTypes']
    StringArray              = definitions['stringArray']
  end
end
